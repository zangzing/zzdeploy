require 'net/ssh'
require 'net/ssh/multi'

class MultiSSH
  attr_reader :amazon, :group_name, :deploy_group, :group_config
  attr_accessor :instances, :longest, :ui, :concurrent_max

  def initialize(amazon, group_name, deploy_group, concurrent_max = 1000)
    @amazon = amazon
    @group_name = group_name
    @deploy_group = deploy_group
    @group_config = deploy_group.config
    @concurrent_max = concurrent_max
    @session = nil
    @ui = Printer.new(STDOUT, STDERR, STDIN)
  end

  def run(remote_cmd)
    @instances ||= amazon.find_and_sort_named_instances(group_name)
    run_instances(@instances, remote_cmd)
  end

  def run_instances(instances, remote_cmd)
    clear_session
    @longest = 0
    @instances = instances
    @instances.each do |instance|
      session_opts = {}
      host = instance[:public_hostname]
      session_opts[:keys] = File.expand_path("~/.ssh/#{group_config[:amazon_security_key]}.pem")
      session_opts[:paranoid] = false
      session_opts[:user_known_hosts_file] = "/dev/null"
      session_opts[:timeout] = 30
      hostspec = "ec2-user@#{host}"
      session.use(hostspec, session_opts)

      @longest = host.length if host.length > @longest
    end

    ssh_command(remote_cmd, session)

    result = 0
    failed_count = 0
    @instances.each do |instance|
      ssh_result = instance[:ssh_exit_status]
      if ssh_result != 0
        failed_count += 1
        result = ssh_result if result == 0
      end
    end

    if failed_count > 0
      raise "Failed SSH command.  Out of #{@instances.count} servers, #{failed_count} failed.  First error was: #{result}"
    else
      ui.msg(ui.color("All #{@instances.count} ssh requests completed without error.", :green, :bold))
    end
  end


  # find a matching instance for the specified host
  def find_instance_by_host(host)
    self.instances.each do |instance|
      if instance[:public_hostname] == host
        return instance
      end
    end
    return nil
  end

  def clear_session
    @session = nil
    # a map that tracks all output data in an array
    # keyed by the host name
    @output_tracker = {}
  end

  def output_tracker
    @output_tracker
  end

  # dump the result data into a file for each host
  def output_tracked_data_to_files(prefix, result_path)
    return if result_path.nil?
    output_tracker.each do |key, data|
      file_path = File.expand_path('.', "#{result_path}/results_#{prefix}_#{key}.txt")
      File.open(file_path, 'w') do |f|
        data.each do |line|
          f.puts(line)
        end
      end
    end
  end

  def add_output(host, msg)
    # see if we already have an entry for this host
    data_array = output_tracker[host]
    if data_array.nil?
      data_array = []
      output_tracker[host] = data_array
    end
    # now add the msg to the array
    data_array << msg
  end

  def session
    return @session unless @session.nil?

    ssh_error_handler = Proc.new do |server|
      host = server.host
      msg = "Failed to connect to #{host} -- #{$!.class.name}: #{$!.message}"
      print_data(host, msg, :red)
      instance = find_instance_by_host(host)
      instance[:ssh_exit_status] = 99
    end

    @session ||= Net::SSH::Multi.start(:concurrent_connections => concurrent_max, :on_error => ssh_error_handler)
  end

  # print and group data by host
  def print_data(host, data, color = :cyan)
    if data =~ /\n/
      data.split(/\n/).each { |d| print_data(host, d) }
    else
      add_output(host, data)
      padding = self.longest - host.length
      str = ui.color(host, color) + (" " * (padding + 1)) + data
      ui.msg(str)
    end
  end

  def ssh_command(command, subsession)
    subsession.open_channel do |ch|
      ch.request_pty
      ch.exec command do |ch, success|
        raise ArgumentError, "Cannot execute #{command}" unless success
        ch.on_data do |ichannel, data|
          print_data(ichannel[:host], data)
        end
        ch.on_extended_data do |ichannel, type, data|
          print_data(ichannel[:host], data, :red)
        end
        ch.on_request("exit-status") do |ichannel, data|
          status = data.read_long
          ichannel[:exit_status] = status
          host = ichannel[:host]
          instance = find_instance_by_host(host)
          instance[:ssh_exit_status] = status
          print_data(host, "Exit status is: #{status}", status == 0 ? :blue : :red)
        end
      end
    end
    session.loop
  end

end
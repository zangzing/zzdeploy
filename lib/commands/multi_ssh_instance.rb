require "set"
require 'readline'

module Commands
  class MultiSSHInstance

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
          :roles => [],
          :instances => []
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
        :group
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: multi_ssh [options]"
      opts.description = "Run a remote command on multiple servers via ssh"

      opts.on('-i', "--instances instance1,instance2,etc", Array, "The instance(s) to connect to.") do |v|
        options[:instances] = v
      end

      opts.on('-r', "--role role1,role2", Array,  "Roles to use.") do |v|
        valid_roles = MetaOptions.roles
        v.each do |r|
          raise "Not a valid role: #{r}" if !valid_roles.include?(r.to_sym)
        end
        options[:roles] = v
      end

      opts.on('-g', "--group deploy_group", "Required: Group to look for.") do |v|
        options[:group] = v
      end

      opts.on('-f', "--file file", "A file that contains the commands to execute.") do |v|
        options[:file] = v
      end

      opts.on('-p', "--print path", "The directory into which we output the data as a file per host.") do |v|
        options[:result_path] = v
      end
    end


    def run(global_options, amazon)
      ec2 = amazon.ec2

      file_path = options[:file]
      if file_path.nil?
        if ARGV.length != 1
          raise "Must include the remote command to run.  Make sure you quote it so it appears as one argument"
        end
        remote_cmd = ARGV[0]
      else
        remote_cmd = File.open(file_path, 'r') {|f| f.read }
      end

      group_name = options[:group]
      deploy_group = amazon.find_deploy_group(group_name)
      group_config = deploy_group.config

      user_instances = options[:instances]
      roles = options[:roles]
      filters_off = roles.empty? && user_instances.empty?
      instances = []  # build the instances wanted here
      server_instances = amazon.find_and_sort_named_instances(options[:group], nil, false)
      server_instances.each do |server_instance|
        server_instance_id = server_instance[:resource_id]
        server_instance_role = server_instance[:role]
        if filters_off || roles.include?(server_instance_role) || user_instances.include?(server_instance_id)
          # include this instance in the result set
          instances << server_instance
        end
      end

      if instances.empty?
         raise "No instances matched your search criteria."
      end

      multi = MultiSSH.new(amazon, group_name, deploy_group)
      multi.run_instances(instances, remote_cmd)
      multi.output_tracked_data_to_files("multi_ssh", options[:result_path])
    end
  end
end

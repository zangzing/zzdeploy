require "set"
require 'readline'

module Commands
  class SSHInstance

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
        :group
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: ssh [options]"
      opts.description = "SSH into a server"

      opts.on('-i', "--instance instance", "The instance to connect to..") do |v|
        options[:instance] = v
      end

      opts.on('-r', "--role role", MetaOptions.roles, "Role to look for.") do |v|
        options[:role] = v
      end

      opts.on('-g', "--group deploy_group", "Required: Group to look for.") do |v|
        options[:group] = v
      end
    end


    def run(global_options, amazon)
      ec2 = amazon.ec2

      group_name = options[:group]
      deploy_group = amazon.find_deploy_group(group_name)
      group_config = deploy_group.config

      pick = nil
      instance_id = options[:instance]
      if instance_id.nil?
        instances = amazon.find_and_sort_named_instances(options[:group], options[:role])
      else
        instances = amazon.find_and_sort_named_instances()
        instances.each do |instance|
          resource_id = instance[:resource_id]
          if resource_id == instance_id
            pick = instance
            break
          end
        end
        if pick.nil?
          raise "The instance you specified was not a valid ZangZing deployed instance."
        end
      end

      if pick.nil?
        if instances.length == 0
          raise "No instance matched your search criteria."
        end

        pick = instances[0]
        if instances.length > 1
          # more than one
          puts "More than one instance matched, pick from list below the instance you want."
          i = 1
          instances.each do |instance|
            name = instance[:Name]
            resource_id = instance[:resource_id]
            puts "#{i}) #{name} => #{resource_id}"
            i += 1
          end
          print "Type the one you want to use: "
          r = Readline.readline()
          pick_num = r.to_i
          if pick_num < 1 || pick_num > instances.length
            raise "Your pick was not in range."
          end
          pick = instances[pick_num - 1]
        end
      end

      # ok, we have a pick lets ssh to it
      ec2_instance = ec2.describe_instances(pick[:resource_id])[0]
      dns_name = ec2_instance[:dns_name]
      puts "Running SSH for #{pick[:Name]}"
      ssh_cmd = "ssh -i ~/.ssh/#{group_config[:amazon_security_key]}.pem ec2-user@#{dns_name}"
      ZZSharedLib::CL.do_cmd ssh_cmd
    end
  end
end

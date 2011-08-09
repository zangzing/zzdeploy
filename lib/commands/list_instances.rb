require "set"

module Commands
  class ListInstances

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
      opts.banner = "Usage: list [options]"
      opts.description = "List the server instances"

      opts.on('-r', "--role role", MetaOptions.roles, "Role to look for.") do |v|
        options[:role] = v
      end

      opts.on('-g', "--group deploy_group", "Required: Group to look for.") do |v|
        options[:group] = v
      end

    end


    def run(global_options, amazon)
      ec2 = amazon.ec2

      instances = amazon.find_and_sort_named_instances(options[:group], options[:role])

      first = true
      instances.each do |instance|
        if first
          s = sprintf("%-40s%-14s%-40s","Name", "Instance", "Public Host")
          puts s
          first = false
        end
        name = instance[:Name]
        resource_id = instance[:resource_id]
        public_host = instance[:public_hostname]
        s = sprintf("%-40s%-14s%-40s",name, resource_id, public_host)
        puts s
      end

    end
  end
end

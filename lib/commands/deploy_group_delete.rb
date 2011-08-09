module Commands
  class DeployGroupDelete

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
          :group,
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: deploy_group_delete [options]"
      opts.description = "Delete a deploy group"

      opts.on('-g', "--group name", "Required - Name of this deploy group.") do |v|
        options[:group] = v
      end

    end


    def run(global_options, amazon)
      group_name = options[:group]

      # first see if already exists
      deploy_group = amazon.find_deploy_group(group_name)

      if deploy_group.nil? || deploy_group[:group] != group_name
        raise "Deploy group not found.  Doing nothing."
      end

      deploy_group.delete
    end
  end
end
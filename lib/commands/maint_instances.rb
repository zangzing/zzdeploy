module Commands
  class MaintInstances

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
          :migrate_command => '',
          :downtime => false
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
          :group,
          :maint,
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: maint [options]"
      opts.description = "Put up or take down the maintenance page."

      opts.on('-g', "--group name", "Required - Name of this deploy group.") do |v|
        options[:group] = v
      end

      opts.on('-m', "--[no-]maint", "Required - Use --maint if you want the maint page, --no-maint to remove the maint page.") do |v|
        options[:maint] = v
      end

      opts.on('-p', "--print path", "The directory into which we output the data as a file per host.") do |v|
        options[:result_path] = v
      end
    end


    def run(global_options, amazon)
      ec2 = amazon.ec2
      utils = ZZSharedLib::Utils.new(amazon)

      group_name = options[:group]
      maint = options[:maint]

      # first see if already exists
      deploy_group = amazon.find_deploy_group(group_name)

      instances = amazon.find_and_sort_named_instances(group_name)

      # see if already deploying
      if !options[:force]
        # raises an exception if not all in the ready or error state
        utils.check_deploy_state(instances, [:deploy_chef, :deploy_app])
      end


      # put up or take down the maint page
      BuildDeployConfig.do_maint_deploy(utils, amazon, instances, group_name, deploy_group, maint, options[:result_path])

    end
  end
end
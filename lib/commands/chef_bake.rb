module Commands
  class ChefBake

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
      opts.banner = "Usage: chef_bake [options]"
      opts.description = "Apply the chef scripts"

      opts.on('-g', "--group name", "Required - Name of this deploy group.") do |v|
        options[:group] = v
      end

      opts.on('-f', "--force", "Force a deploy even if the current status says we are deploying.  You should only do this if you are certain the previous deploy is stuck.") do |v|
        options[:force] = v
      end
    end


    def run(global_options, amazon)
      ec2 = amazon.ec2
      utils = ZZSharedLib::Utils.new(amazon)

      group_name = options[:group]

      # first see if already exists
      deploy_group = amazon.find_deploy_group(group_name)

      recipes_deploy_tag = deploy_group.recipes_deploy_tag

      instances = amazon.find_and_sort_named_instances(group_name)

      # see if already deploying
      if !options[:force]
        # raises an exception if not all in the none state
        utils.check_deploy_state(instances, [:deploy_chef, :deploy_app])
      end

      # verify that the chef deploy tag exists
      cmd = "git ls-remote --tags git@github.com:zangzing/zz-chef-repo.git refs/tags/#{recipes_deploy_tag} | egrep refs/tags/#{recipes_deploy_tag}"
      if ZZSharedLib::CL.do_cmd_result(cmd) != 0
        raise "Could not find the tag: #{recipes_deploy_tag} in the remote zz-chef-repo repository.  Make sure you check in and tag your code, and run chef_upload."
      end

      # tag is good, go ahead and deploy to all the machines in the group
      BuildDeployConfig.do_config_deploy(utils, amazon, instances, group_name, deploy_group, options[:result_path])
    end
  end
end
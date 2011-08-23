module Commands
  class DeployInstances

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
          :migrate_command => '',
          :downtime => false,
          :no_restart => false
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
          :group,
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: deploy [options]"
      opts.description = "Deploy the applications for the specified group"

      opts.on('-g', "--group name", "Required - Name of this deploy group.") do |v|
        options[:group] = v
      end

      opts.on('-t', "--tag tag", "Required - Git tag to use for pulling chef code.") do |v|
        options[:tag] = v
      end

      opts.on('-m', "--migrate [command]", "Migrate command to run.  Does not force downtime, use the --downtime option for that.") do |v|
        options[:migrate_command] = v || 'rake db:migrate'
      end

      opts.on('-d', "--downtime", "If this flag is set we bring the server down and bring up the maint page during the restart phase.") do |v|
        options[:downtime] = v
      end

      opts.on("--no_restart", "Set this if you only want the deploy without a restart, useful for creating AMI images.") do |v|
        options[:no_restart] = v
      end

      opts.on('-f', "--force", "Force a deploy even if the current status says we are deploying.  You should only do this if you are certain the previous deploy is stuck.") do |v|
        options[:force] = v
      end

      opts.on('-p', "--print path", "The directory into which we output the data as a file per host.") do |v|
        options[:result_path] = v
      end
    end


    def run(global_options, amazon)
      ec2 = amazon.ec2
      utils = ZZSharedLib::Utils.new(amazon)

      group_name = options[:group]
      migrate_command = options[:migrate_command]
      downtime = options[:downtime]
      app_deploy_tag = options[:tag]
      no_restart = options[:no_restart]

      # first see if already exists
      deploy_group = amazon.find_deploy_group(group_name)

      group_config = deploy_group.config
      gitrepo = group_config[:app_git_url]

      # verify that the chef deploy tag exists
      full_ref = "refs/heads/#{app_deploy_tag}"
      cmd = "git ls-remote #{gitrepo} #{full_ref} | egrep #{full_ref}"
      if ZZSharedLib::CL.do_cmd_result(cmd) != 0
        # now try to see if it's a tag - use the ^{} to follow tags to find the matching non tag object (i.e. the proper checkin that we tagged)
        full_ref = "refs/tags/#{app_deploy_tag}"
        cmd = "git ls-remote #{gitrepo} #{full_ref}^{} #{full_ref} | egrep #{full_ref}"
        if ZZSharedLib::CL.do_cmd_result(cmd) != 0
          raise "Could not find the tag or ref: #{app_deploy_tag} in the remote #{gitrepo} repository."
        end
      end

      deploy_group.app_deploy_tag = app_deploy_tag
      deploy_group.save
      deploy_group.reload # save corrupts the in memory state so must reload, kinda lame


      instances = amazon.find_and_sort_named_instances(group_name)

      # see if already deploying
      if !options[:force]
        # raises an exception if not all in the ready or error state
        utils.check_deploy_state(instances, [:deploy_chef, :deploy_app])
      end


      # tag is good, go ahead and deploy to all the machines in the group
      # this is a two phase operation.  The first pushes the code and preps everything
      # up to the point of a before restart operation.  We then call again to
      # perform the restart.  This ensures that all servers were prepped before
      # we try to restart to minimize the chance of issues.
      BuildDeployConfig.do_app_deploy(utils, amazon, instances, group_name, deploy_group, migrate_command, downtime, no_restart, options[:result_path])
      ui = Printer.new(STDOUT, STDERR, STDIN)
      ui.msg(ui.color("Your app has been successfully deployed - open for business.", :green, :bold, :reverse))

    end
  end
end
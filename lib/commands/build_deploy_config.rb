module Commands

  # this class builds up the contents of the json deploy file that we feed
  # to the remote system to kickstart the chef run.  It allows us to
  # dynamically configure the options we want
  class BuildDeployConfig

    def self.build_json(zz_options, deploy_file)
      chef_config = { :run_list => "recipe[deploy-manager]" }
      zz_options[:dev_machine] = false
      chef_config[:zz] = zz_options

      json = JSON.pretty_generate(chef_config)

      # now build up the command string to run
      cmd =
"bash -l -c '(
cat <<'EOP'
#{json}
EOP
) > /var/chef/#{deploy_file}.json
cd #{::ZZDeploy::RECIPES_DIR}
sudo bundle exec chef-solo -l debug -c chef-local/remote_solo.rb -j /var/chef/#{deploy_file}.json'"

      return cmd
    end

    def self.remote_app_deploy(migrate_command, downtime)
      zz = {
          :deploy_what => "app",
          :deploy_migrate_command => migrate_command,
          :deploy_downtime => downtime
      }
      return build_json(zz, 'deploy_app')
    end

    def self.remote_app_restart(migrate_command, downtime)
      zz = {
          :deploy_what => "app_restart",
          :deploy_migrate_command => migrate_command,
          :deploy_downtime => downtime
      }
      return build_json(zz, 'deploy_app_restart')
    end

    def self.remote_app_maint(maint)
      zz = {
          :deploy_what => "app_maint",
          :deploy_maint => maint
      }
      return build_json(zz, 'deploy_app_maint')
    end

    def self.remote_config_deploy
      zz = {
          :deploy_what => "config"
      }
      return build_json(zz, 'deploy_config')
    end

    def self.remote_shutdown
      zz = {
          :deploy_what => "shutdown"
      }
      return build_json(zz, 'deploy_shutdown')
    end

    def self.do_remote_shutdown(utils, amazon, instances, group_name, deploy_group, result_path)
      begin
        remote_cmd = remote_shutdown
        multi = MultiSSH.new(amazon, group_name, deploy_group)
        multi.run_instances(instances, remote_cmd)
      rescue Exception => ex
        # ignore any errors since we want to shut down regardless
      ensure
        multi.output_tracked_data_to_files("remote_shutdown", result_path) rescue nil
      end
    end

    def self.do_config_deploy(utils, amazon, instances, group_name, deploy_group, result_path)
      begin
        utils.mark_deploy_state(instances, :deploy_chef, ZZSharedLib::Utils::START)
        remote_cmd = remote_config_deploy
        multi = MultiSSH.new(amazon, group_name, deploy_group)
        multi.run_instances(instances, remote_cmd)
      rescue Exception => ex
        raise ex
      ensure
        multi.output_tracked_data_to_files("deploy_chef", result_path) rescue nil
        # only mark ready if not in error state
        utils.mark_deploy_state(instances, :deploy_chef, ZZSharedLib::Utils::READY, true)
      end
    end

    def self.do_app_deploy(utils, amazon, instances, group_name, deploy_group, migrate_command, downtime, no_restart, result_path)
      # ok, phase one is to do everything up to but not including the restart
      begin
        utils.mark_deploy_state(instances, :deploy_app, ZZSharedLib::Utils::START)
        remote_cmd = remote_app_deploy(migrate_command, downtime)
        multi = MultiSSH.new(amazon, group_name, deploy_group)
        multi.run_instances(instances, remote_cmd)
      rescue Exception => ex
        raise ex
      ensure
        multi.output_tracked_data_to_files("app_deploy", result_path) rescue nil
      end

      # the prep is good and all servers are ready to restart
      begin
        if no_restart == false
          puts "Restarting servers..."
          utils.mark_deploy_state(instances, :deploy_app, ZZSharedLib::Utils::RESTARTING)
          remote_cmd = remote_app_restart(migrate_command, downtime)
          multi.run_instances(instances, remote_cmd)
        end
      rescue Exception => ex
        raise ex
      ensure
        multi.output_tracked_data_to_files("app_restart", result_path) rescue nil
        # mark as ready unless they are in the error state already
        utils.mark_deploy_state(instances, :deploy_app, ZZSharedLib::Utils::READY, true)
      end
    end

    # turn off or on the maintenance mode
    def self.do_maint_deploy(utils, amazon, instances, group_name, deploy_group, maint, result_path)
      begin
        utils.mark_deploy_state(instances, :deploy_app, ZZSharedLib::Utils::MAINT)
        remote_cmd = remote_app_maint(maint)
        multi = MultiSSH.new(amazon, group_name, deploy_group)
        multi.run_instances(instances, remote_cmd)
      rescue Exception => ex
        raise ex
      ensure
        multi.output_tracked_data_to_files("app_maint", result_path) rescue nil
        # only mark ready if not in error state
        utils.mark_deploy_state(instances, :deploy_app, ZZSharedLib::Utils::READY, true)
      end
    end

  end

end
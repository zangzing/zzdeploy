
module Commands
  class DeleteInstances

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
          :force_delete => false
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
          :instances,
          :group
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: delete [options]"
      opts.description = "Delete server instance(s)"

      opts.on('-i', "--instance instance1,instance2,etc", Array, "The instance(s) to delete.") do |v|
        options[:instances] = v
      end

      opts.on('-g', "--group deploy_group", "Required - The deploy group we are in.  A deploy group is a set of servers that are required to run the infrastructure for a server.") do |v|
        options[:group] = v
      end

      opts.on('-f', "--force", "Force a deletion of a restricted app type (such as db or app_master).  App will most likely fail to operate properly after this.") do |v|
        options[:force_delete] = v
      end

      opts.on('-w', "--wait", "Wait until the instance has completely shut down and terminated.  Otherwise, we return immediately after starting the terminate.") do |v|
        options[:wait] = v
      end

      opts.on('-p', "--print path", "The directory into which we output the data as a file per host.") do |v|
        options[:result_path] = v
      end
    end


    def run(global_options, amazon)
      ec2 = amazon.ec2
      elb = amazon.elb
      utils = ZZSharedLib::Utils.new(amazon)

      group_name = options[:group]
      deploy_group = amazon.find_deploy_group(group_name)
      group_config = deploy_group.config
      amazon_elb = group_config[:amazon_elb]

      inst_ids = options[:instances]
      if options[:force_delete] == false
        # check to see if restricted type
        inst_ids.each do |inst_id|
          flat = amazon.flat_tags_for_resource(inst_id)
          role = flat[:role]
          role = role.to_sym unless role.nil?
          case role
            when :app_master, :db
              raise "You cannot delete an instance with a role of #{role}.  Doing so will cause the server to not operate.  You can force with the --force option."
          end
        end
      end


      amazon.flush_tags    # force a refresh of the cached tags
      all_instances = amazon.find_and_sort_named_instances(group_name)

      instances = all_instances.reject { |inst| inst_ids.include?(inst[:resource_id]) == false }

      # call servers to perform clean shutdown
      puts "Attempting to perform clean shutdown on remote machines.  Will ignore any errors and continue with shutdown."
      BuildDeployConfig.do_remote_shutdown(utils, amazon, instances, group_name, deploy_group, options[:result_path]) rescue nil

      # mark state on machines as deleted
      ec2.create_tags(inst_ids, {:state => 'delete' })

      # now shut them down
      ec2.terminate_instances([inst_ids])
      inst_ids.each do |inst_id|
        puts "Instance #{inst_id} is terminating."
      end
      if options[:wait] == true
        puts "Waiting for instances to terminate."
        while true do
          print "."
          STDOUT.flush
          sleep(1)
          instances = ec2.describe_instances(inst_ids)
          all_terminated = true
          instances.each do |instance|
            if instance[:aws_state] != "terminated"
              all_terminated = false
              break
            end
          end
          break if all_terminated
        end
      end

      # we may want to kick off a redeploy of the chef config and app since the configuration of the
      # group changed.  Right now we leave this up to the caller since they may want to do it after
      # deleting more than one instance to avoid multiple redeploys
      puts
      puts "Since the configuration has changed you should redeploy the configuration and application using chef_bake and deploy."
    end
  end
end

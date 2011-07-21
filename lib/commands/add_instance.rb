module Commands
  class AddInstance

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
          :instance_size => "c1.medium",
          :start_app => false,
          :availability_zone => "us-east-1c"   # this is where our reserved instance currently are
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
          :role,
          :group,
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: add [options]"
      opts.description = "Add a server instance"

      opts.on('-s', "--size instance_size", ["t1.micro", "m1.small", "c1.medium"], "The amazon instance size - currently we limit to 32 bit instances.") do |v|
        options[:instance_size] = v
      end

      opts.on('-z', "--zone availability_zone", MetaOptions.availability_zones, "The amazon availability zone - currently only east coast.") do |v|
        options[:availability_zone] = v
      end

      opts.on('-r', "--role role", MetaOptions.roles, "Required - Role server will play.") do |v|
        options[:role] = v
      end

      opts.on("--start_app","Set if you want to deploy and start the app after instance is ready.") do |v|
        options[:start_app] = v
      end

      opts.on('-e', "--extra extra", MetaOptions.roles, "Optional extra data associated with this instance.") do |v|
        options[:extra] = v
      end

      opts.on('-g', "--group deploy_group", "Required - The deploy group we are in.  A deploy group is a set of servers that are required to run the infrastructure for a server.") do |v|
        options[:group] = v
      end

      opts.on('-p', "--print path", "The directory into which we output the data as a file per host.") do |v|
        options[:result_path] = v
      end
    end


    def run(global_options, amazon)
      ec2 = amazon.ec2
      utils = ZZSharedLib::Utils.new(amazon)

      user_json = JSON.pretty_generate(options)

      # deploy group
      group_name = options[:group]
      role = options[:role]
      extra = options[:extra]
      start_app = options[:start_app]

      # first see if already exists
      deploy_group = amazon.find_deploy_group(group_name)
      recipes_deploy_tag = deploy_group.recipes_deploy_tag
      group_config = deploy_group.config

      availability_zone = options[:availability_zone] || group_config[:availability_zone]

      # the security key
      security_key = group_config[:amazon_security_key]

      # the security group
      security_group = group_config[:amazon_security_group]

      # find ones matching the role
      match = amazon.find_by_role(group_name, role)

      # stop if we have a case where we only allow one of a particular kind
      case role.to_sym
        when :app_master, :db, :solo
          if match.length > 0
            raise "Argument error: You already have a duplicate role of #{role}.  The existing instance is #{match[0]}."
          end
      end

      # now find the proper AMI image to use
      baseline_image = group_config[:amazon_image]

      # first see if we have a specific image for this role
      role_image = "#{baseline_image}_#{role}"
      match_image = amazon.find_typed_resource("image", "Name", role_image)
      if match_image.length > 1
        raise "You must have only one AMI Image for #{role_image}.  Found: #{match_image.length}"
      end

      if match_image.length != 1
        # didn't have a specific role image so get the generic one
        match_image = amazon.find_typed_resource("image", "Name", baseline_image)
        if match_image.length != 1
          raise "Need to have exactly one AMI Image for #{baseline_image}.  Found: #{match_image.length}"
        end
      end


      instances = ec2.run_instances(match_image[0], 1, 1, [security_group], security_key, user_json, nil, options[:instance_size],
                                    nil, nil, availability_zone)
      inst_id = instances[0][:aws_instance_id]
      puts "Waiting for instance #{inst_id} to boot"
      aws_state = ""
      instance = nil
      waits = 0
      while aws_state != "running" do
        print "."
        STDOUT.flush
        sleep(1)
        waits += 1
        # this silly bit of logic is needed because sometimes Amazons API does not know
        # about the newly created instance for a brief period so don't ask till we give it
        # a chance to learn about it
        if waits >= 10
          instance = ec2.describe_instances(inst_id)[0]
          aws_state = instance[:aws_state]
        end
      end
      puts
      puts "Tagging instance."
      ec2.create_tags(inst_id, {"Name" => "#{group_name}_#{role}_#{inst_id}", :group => group_name, :role => role, :extra => extra,
                                :state => 'booting', :deploy_app => ZZSharedLib::Utils::NEVER, :deploy_chef => ZZSharedLib::Utils::NEVER })

      dns_name = instance[:dns_name]
      ssh_cmd = "ssh -t -i ~/.ssh/#{group_config[:amazon_security_key]}.pem ec2-user@#{dns_name}"
      puts ssh_cmd
      test_cmd = 'echo "connected"'
      test_cmd = "#{ssh_cmd} '#{test_cmd}'"
      tries = 0
      while true do
        puts "testing ssh connection"
        result = ZZSharedLib::CL.do_cmd_result test_cmd
        break if result == 0
        sleep(6)
        tries += 1
        if tries >= 10
          # todo decide if we should terminate this instance
          ec2.create_tags(inst_id, {:state => 'failed_boot' })
          raise "Not able to establish ssh connection, make sure the security group has the ssh port open."
        end
      end

      # if we get here we should have verified that the machine is ready and we can ssh into it, lets
      # do the initial upload step for the chef recipes by fetching the proper tag on the remote machine
      ec2.create_tags(inst_id, {:state => 'ready' })

      git_cmd = "cd #{::ZZDeploy::RECIPES_DIR} && git fetch && git checkout -f #{recipes_deploy_tag} && bundle install"
      remote_cmd = "#{ssh_cmd} \"#{git_cmd}\""
      result = ZZSharedLib::CL.do_cmd_result remote_cmd
      if result != 0
        raise "The instance was created but we were unable to upload the chef recipes.\nYou should try again by using 'chef_upload' and make sure you have a valid git tag."
      end

      # set up our instance id
      # first get all instances in our group which should include us
      amazon.flush_tags    # force a refresh of the cached tags
      all_instances = amazon.find_and_sort_named_instances(group_name)

      just_our_instance = all_instances.reject { |inst| inst[:resource_id] != inst_id }

      # deploy the chef config
      puts "Updating chef configuration for new instance."
      BuildDeployConfig.do_config_deploy(utils, amazon, just_our_instance, group_name, deploy_group, options[:result_path])

      # optionally deploy and start app
      # note in this case we redeploy the whole group since
      # there are dependencies between the instances
      if start_app
        puts "Now deploying all app instances since the configuration changed."
        BuildDeployConfig.do_app_deploy(utils, amazon, all_instances, group_name, deploy_group, '', false, false, options[:result_path]) if start_app
      end

    end
  end
end
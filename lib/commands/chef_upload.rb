module Commands
  class ChefUpload

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
          :tag,
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: chef_upload [options]"
      opts.description = "Upload the chef scripts"

      opts.on('-g', "--group name", "Required - Name of this deploy group.") do |v|
        options[:group] = v
      end

      opts.on('-t', "--tag tag", "Required - Git tag to use for pulling chef code.") do |v|
        options[:tag] = v
      end
    end


    def run(global_options, amazon)
      ec2 = amazon.ec2

      group_name = options[:group]
      recipes_deploy_tag = options[:tag]

      # first see group exists
      deploy_group = amazon.find_deploy_group(group_name)

      # verify that the tag given is on the remote repo
      cmd = "git ls-remote --tags git@github.com:zangzing/zz-chef-repo.git refs/tags/#{recipes_deploy_tag} | egrep refs/tags/#{recipes_deploy_tag}"
      if ZZSharedLib::CL.do_cmd_result(cmd) != 0
        raise "Could not find the tag specified in the remote zz-chef-repo repository.  Make sure you check in and tag your code."
      end

      # tag is good, go ahead and upload to simple db
      deploy_group.recipes_deploy_tag = recipes_deploy_tag
      deploy_group.save
      deploy_group.reload # save corrupts the in memory state so must reload, kinda lame

      remote_cmd = ChefUpload.get_upload_command(recipes_deploy_tag)
      multi = MultiSSH.new(amazon, group_name, deploy_group)
      multi.run(remote_cmd)
    end

    def self.get_upload_command(recipes_deploy_tag)
      "cd #{::ZZDeploy::RECIPES_DIR} && git fetch && git checkout -f #{recipes_deploy_tag} && bundle install --path #{::ZZDeploy::RECIPES_BUNDLE_DIR} --deployment"
    end
  end
end
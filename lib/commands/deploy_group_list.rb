module Commands
  class DeployGroupList

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: list_deploy_groups [options]"
      opts.description = "List the deploy groups"

    end


    def run(global_options, amazon)
      ec2 = amazon.ec2

      # first see if already exists
      deploy_groups = ZZSharedLib::DeployGroupSimpleDB.find_all_by_zz_object_type(ZZSharedLib::DeployGroupSimpleDB.object_type, :auto_load => true)

      deploy_groups.each do |deploy_group|
        puts "Name: #{deploy_group[:group]}"
        puts "Recipes_deploy_tag: #{deploy_group[:recipes_deploy_tag]}"
        puts "App_deploy_tag: #{deploy_group[:app_deploy_tag]}"
        puts "Config Json:"
        pretty = JSON.pretty_generate(deploy_group.config)
        puts "#{pretty}"
        puts
      end
    end
  end
end
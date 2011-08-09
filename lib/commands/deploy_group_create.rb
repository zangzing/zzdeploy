module Commands
  class DeployGroupCreate

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
          :amazon_elb => ''
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
          :group,
          :app_name,
          :rails_env,
          :vhost,
          :email_host,
          :app_git_url,
          :amazon_security_key,
          :amazon_security_group,
          :amazon_image,
          :database_host,
          :database_username,
          :database_password,
          :database_schema
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: deploy_group_create [options]"
      opts.description = "Create a deploy group"

      opts.on('-g', "--group name", "Required - Name of this deploy group.") do |v|
        options[:group] = v
      end

      opts.on("--app_name appname", "Required - Name of the application.") do |v|
        options[:app_name] = v
      end

      opts.on("--rails_env rails_env", "Required - The rails environment to use on deploy.") do |v|
        options[:rails_env] = v
      end

      opts.on("--vhost vhost", "Required - The vhost your server will be deployed as.") do |v|
        options[:vhost] = v
      end

      opts.on("--email_host emailhost", "Required - The email host name to use for incomming email processing.") do |v|
        options[:email_host] = v
      end

      opts.on("--app_git_url app_git_url", "Required - Git URL to fetch code from.") do |v|
        options[:app_git_url] = v
      end

      opts.on("--extra_json_file extra", "Optional - A file with JSON that has application custom context associated with this deploy group.") do |v|
        options[:extra_json_file] = v
      end

      opts.on("--zone availability_zone", MetaOptions.availability_zones, "The amazon availability zone - currently only east coast.") do |v|
        options[:availability_zone] = v
      end

      opts.on("--amazon_security_key key", "Required - The SSH key name to use, assumes pre-configured on Amazon.") do |v|
        options[:amazon_security_key] = v
      end

      opts.on("--amazon_security_group group", "Required - The amazon security group, assumes pre-configured on Amazon.") do |v|
        options[:amazon_security_group] = v
      end

      opts.on("--amazon_image ami", "Required - The baseline Amazon image to use, assumes pre-configured on Amazon.") do |v|
        options[:amazon_image] = v
      end

      opts.on("--amazon_elb load_balancer", "Optional - The elastic load balancer we operate under.") do |v|
        options[:amazon_elb] = v
      end

      opts.on("--database_host database", "Required - The database host name.") do |v|
        options[:database_host] = v
      end

      opts.on("--database_username username", "Required - The database user name name.") do |v|
        options[:database_username] = v
      end

      opts.on("--database_password password", "Required - The database password.") do |v|
        options[:database_password] = v
      end

      opts.on("--database_schema schema", "Required - The database schema name.") do |v|
        options[:database_schema] = v
      end

    end


    def run(global_options, amazon)
      group_name = options[:group]
      extra_file = options[:extra_json_file]
      if !extra_file.nil?
        # they are passing a path to a file containing custom json so add it to the extra field
        options.delete(:extra_json_file)
        json = File.open(extra_file, 'r') {|f| f.read }
        # make sure we can parse into a hash
        extra = JSON.parse(json)
        options[:extra] = extra
      end
      config_json = JSON.fast_generate(options)

      # first see if already exists
      deploy_group = ZZSharedLib::DeployGroupSimpleDB.find_by_zz_object_type_and_group(ZZSharedLib::DeployGroupSimpleDB.object_type, group_name, :auto_load => true)

      if !deploy_group.nil?
        raise "This deploy group already exists.  Doing nothing."
      end

      deploy_group = ZZSharedLib::DeployGroupSimpleDB::create(:zz_object_type => ZZSharedLib::DeployGroupSimpleDB.object_type, :group => group_name,
                                                              :config_json => config_json, :recipes_deploy_tag => "origin/master", :app_deploy_tag => "master",
                                                              :created_at => Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'))

    end
  end
end
module Commands
  class DeployGroupModify

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
          :group,
          :extra_json_file
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
          :group,
          :extra_json_file
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: deploy_group_modify [options]"
      opts.description = "Lets you modify the app extra data by replacing the current extra data with the new data supplied."

      opts.on('-g', "--group name", "Required - Name of this deploy group.") do |v|
        options[:group] = v
      end

      opts.on('-e', "--extra_json_file extra", "Required - A file with JSON that has application custom context associated with this deploy group.") do |v|
        options[:extra_json_file] = v
      end

    end


    def run(global_options, amazon)
      ec2 = amazon.ec2

      group_name = options[:group]
      extra_file = options[:extra_json_file]
      if !extra_file.nil?
        # they are passing a path to a file containing custom json so add it to the extra field
        json = File.open(extra_file, 'r') {|f| f.read }
        # make sure we can parse into a hash
        extra = JSON.parse(json)
        options[:extra] = extra
      end

      # get the existing deploy group
      deploy_group = amazon.find_deploy_group(group_name)
      config = deploy_group.config
      extra_file = options[:extra_json_file]

      # open up the specified file with the json and parse
      json = File.open(extra_file, 'r') {|f| f.read }
      # make sure we can parse into a hash
      extra = JSON.parse(json)

      # ok, now set or replace any existing extra data
      config[:extra] = extra
      deploy_group.config = config
      deploy_group.save
    end
  end
end

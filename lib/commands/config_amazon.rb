
module Commands
  class ConfigAmazon

    # holds the options that were passed
    # you can set any initial defaults here
    def options
      @options ||= {
      }
    end

    # required options
    def required_options
      @required_options ||= Set.new [
          :access_key,
          :secret_key
      ]
    end

    def register(opts, global_options)
      opts.banner = "Usage: config_amazon [options]"
      opts.description = "Write the amazon key configuration"

      opts.on("--akey AmazonAccessKey", "Required: Amazon access key, or environment AWS_ACCESS_KEY_ID.") do |v|
        options[:access_key] = v
      end

      opts.on("--skey AmazonSecretKey", "Required: Amazon secret key or environment AWS_SECRET_ACCESS_KEY") do |v|
        options[:secret_key] = v
      end
    end


    def run(global_options, amazon)
      ec2 = amazon.ec2

      access_key = options[:access_key]
      secret_key = options[:secret_key]

      info = {
          :aws_access_key_id => access_key,
          :aws_secret_access_key => secret_key
      }

      # make sure the chef dir exists
      chef_dir = "/var/chef"
      `sudo mkdir -p #{chef_dir}`

      # generate the json into a temp file
      json = JSON.pretty_generate(info)
      amazon_path = "#{chef_dir}/amazon.json"
      temp_path = File.expand_path('.', "~/amazon_temp.json")
      File.open(temp_path, 'w') {|f| f.write(json) }

      # now move the file and set permissions
      `sudo cp #{temp_path} #{amazon_path}`
      cmd = "sudo chown `whoami` #{amazon_path} && sudo chmod 0644 #{amazon_path}"
      `#{cmd}`
      # remove the temp file
      `rm -f #{temp_path}`
      puts "Your amazon config has been saved to #{amazon_path}"
    end
  end
end

$:.unshift(File.dirname(__FILE__))
models = File.expand_path('../../models', __FILE__)
$:.unshift(models)
require 'subcommand'
require 'commands'
require 'right_aws'
require 'sdb/active_sdb'
require 'json'
require 'zzsharedlib'

class ZZDeploy
  include Subcommands

  VERSION = "0.0.4"
  CMD = "zz"

  RECIPES_DIR = "/var/chef/cookbooks/zz-chef-repo"
  RECIPES_BUNDLE_DIR = "/var/chef/cookbooks/zz-chef-repo_bundle"

  # required options
  def required_options
    @required_options ||= Set.new [
    ]
  end

  # the options that were set
  def options
    @options ||= {}
  end

  def sub_commands
    @sub_commands ||= {}
  end

  def printer
    @printer ||= Printer.new
  end

  # define sub commands here
  def define_sub_commands
    sub_commands[:deploy_group_create] = Commands::DeployGroupCreate.new
    sub_commands[:deploy_group_delete] = Commands::DeployGroupDelete.new
    sub_commands[:deploy_group_list] = Commands::DeployGroupList.new
    sub_commands[:deploy_group_modify] = Commands::DeployGroupModify.new
    sub_commands[:add] = Commands::AddInstance.new
    sub_commands[:delete] = Commands::DeleteInstances.new
    sub_commands[:list] = Commands::ListInstances.new
    sub_commands[:deploy] = Commands::DeployInstances.new
    sub_commands[:maint] = Commands::MaintInstances.new
    sub_commands[:ssh] = Commands::SSHInstance.new
    sub_commands[:multi_ssh] = Commands::MultiSSHInstance.new
    sub_commands[:chef_upload] = Commands::ChefUpload.new
    sub_commands[:chef_bake] = Commands::ChefBake.new
    sub_commands[:config_amazon] = Commands::ConfigAmazon.new
  end

  def setup
    options.clear
    set_amazon_options
    # global options
    global_options do |opts|
      opts.banner = "Version: #{VERSION} - Usage: #{CMD} [options] [subcommand [options]]"
      opts.description = "ZangZing configuration and deploy tool.  You must specify a valid sub command."
      opts.separator ""
      opts.separator "Global options are:"
      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options[:verbose] = v
      end

      opts.on("--akey AmazonAccessKey", "Amazon access key, or environment AWS_ACCESS_KEY_ID.") do |v|
        options[:access_key] = v
      end

      opts.on("--skey AmazonSecretKey", "Amazon secret key or environment AWS_SECRET_ACCESS_KEY") do |v|
        options[:secret_key] = v
      end

    end
    add_help_option

    define_sub_commands

    sub_commands.each_pair do |command_name, sub_cmd|
      command command_name do |opts|
        sub_cmd.send("register", opts, options)
      end
    end

  end

  def force_fail(cmd = nil)
    # force failure and show options
    ARGV.clear
    ARGV << "help"
    ARGV << cmd unless cmd.nil?
    opt_parse
  end

  # validate the options passed
  def validate(cmd, sub_cmd)
    required_options.each do |r|
      if options.has_key?(r) == false
        puts "Missing options"
        force_fail
      end
    end

    sub_cmd.required_options.each do |r|
      if sub_cmd.options.has_key?(r) == false
        puts "Missing options"
        force_fail(cmd)
      end
    end
  end

  def set_amazon_options
    json = File.open("/var/chef/amazon.json", 'r') {|f| f.read }
    ak = JSON.parse(json)
    options[:access_key] = ak["aws_access_key_id"]
    options[:secret_key] = ak["aws_secret_access_key"]
  rescue
    # do nothing
  end

  def parse
    if ARGV.empty?
      ARGV << "help"
    end

    cmd = opt_parse()
    if cmd.nil?
      force_fail
    end

    # ok, we have a valid command so dispatch it
#    puts "cmd: #{cmd}"
#    puts "options ......"
#    p options
#    puts "ARGV:"
#    p ARGV

    sub_cmd = sub_commands[cmd.to_sym]
    validate(cmd, sub_cmd)

    # track both types of options
    ZZSharedLib::Options.global_options = options
    ZZSharedLib::Options.cmd_options = sub_cmd.options

    # dispatch the command
    amazon = ZZSharedLib::Amazon.new

    sub_cmd.send("run", options, amazon)
  end



  def run(argv = ARGV)
    exit_code = true
    begin
      setup
      parse
    rescue SystemExit => ex
      # ignore direct calls to exit
    rescue Exception => ex
      printer.error printer.color(ex.message, :red)
#      puts ex.backtrace
      exit_code = false
    end

    # make sure buffer is flushed
    # debugger doesn't seem to do this always
    STDOUT.flush

    return exit_code
  end

  def print_actions
    cmdtext = "Commands are:"
    @commands.sort.map do |c, opt|
      #puts "inside opt.call loop"
      desc = opt.call.description
      cmdtext << "\n   #{c} : #{desc}"
    end

    # print aliases
    unless @aliases.empty?
      cmdtext << "\n\nAliases: \n"
      @aliases.each_pair { |name, val| cmdtext << "   #{name} - #{val}\n"  }
    end

    cmdtext << "\n\nSee '#{CMD} help COMMAND' for more information on a specific command."
  end

end

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "rspec"

describe_tags "Real Tests" do
  it "should do something" do
    zz = ZZDeploy.new()
    puts zz.test

    ARGV.clear
    ARGV << "add"
    ARGV << "--roles"
    ARGV << "app,util"
    zz.run

    ARGV.clear
    ARGV << "remove"
    ARGV << "--instance"
    ARGV << "i1,i2"
    zz.run

    ARGV.clear
    ARGV << "list"
    ARGV << "--roles"
    ARGV << "app"
    zz.run
  end
end
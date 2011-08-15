# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'info'
 
Gem::Specification.new do |s|
  s.name                      = "zzdeploy"
  s.version                   = Info.version
  s.platform                  = Gem::Platform::RUBY
  s.required_ruby_version     = '>= 1.8'
  s.required_rubygems_version = ">= 1.3"
  s.authors                   = ["Greg Seitz"]
  s.summary                   = "ZangZing Amazon Deploy tools"
  s.description               = "Allows configuration and management of rails apps on Amazon EC2 instances"
  
  s.add_dependency "subcommand", ">= 1.0.0"
  s.add_dependency "right_aws", ">= 1.3.0"
  s.add_dependency "json", "= 1.5.2"
  s.add_dependency "net-ssh-multi", ">= 1.1"
  s.add_dependency "highline", ">= 1.6.2"
  s.add_dependency "zzsharedlib", ">= 0.0.5"

  s.add_development_dependency('rake', '~> 0.9.2')
  s.add_development_dependency('rspec', '~> 2.4')
 
  s.files        = Dir.glob("{lib}/**/*") + %w(bin/zz Rakefile LICENSE README.rdoc)
  s.test_files = [
    "spec/spec_helper.rb"
  ]
  
  s.rdoc_options = ["--charset=UTF-8"]
  s.bindir       = "bin"
  s.executables  = %w( zz )
  s.require_paths = ['lib','lib/commands']
end
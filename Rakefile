require "bundler/gem_tasks"
require 'rake/testtask'
require 'gpgme'
require 'byebug'

def setup_gpg
  # TODO do we need this?
  ENV['GPG_AGENT_INFO'] = '' # disable gpg agent
end

task :default => ["mail_gpg:tests:setup", :test]

namespace :mail_gpg do
  namespace :tests do
    task :setup do
      setup_gpg
    end
  end
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.test_files = FileList['test/**/*_test.rb']
  test.verbose = true
  test.warning = false
end


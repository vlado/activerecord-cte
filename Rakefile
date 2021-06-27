# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

namespace :test do
  desc "Will run the tests in all db adapters - AR version combinations"
  task :matrix do
    require "English"
    system("docker-compose build && docker-compose run lib bin/test")
    exit($CHILD_STATUS.exitstatus) unless $CHILD_STATUS.success?
  end
end

require "cucumber/rake/task"

task :default => ["validate"]


Cucumber::Rake::Task.new(:validate) do |task|
  require 'dotenv'; Dotenv.load
  task.cucumber_opts = ["-s","-c", "features" ]
end
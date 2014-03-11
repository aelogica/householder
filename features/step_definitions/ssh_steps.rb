Given(/^I initialize password\-less SSH access$/) do
end

Given(/^I connect to a running system interactively$/) do
  @command = "ssh -T #{ENV['REMOTE_USER']}@#{ENV['REMOTE_HOST']}"
  unless @command.nil?
    steps %Q{ When I run `#{@command}` interactively }
  end
end

When /^I disconnect$/ do
  steps %Q{ When I type "exit $?" }
end

Then(/^I should see the remote username$/) do
  @remote_user = ENV['REMOTE_USER']
  steps %Q{ Then the stdout should contain "#{@remote_user}" }
end
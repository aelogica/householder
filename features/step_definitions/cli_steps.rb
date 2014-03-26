Then(/^I should see the help text$/) do
  usage = "Usage: house"
  steps %Q{ Then the stdout should contain "#{usage}" } 
end

When(/^I run the command to house the box$/) do
  house = "house #{ENV['BOX_URL']} #{ENV['BOX_NAME']} #{ENV['REMOTE_USER']} #{ENV['REMOTE_HOST']} #{ENV['BOX_IP']} #{ENV['BOX_USERNAME']} #{ENV['BOX_PASSWORD']} #{ENV['BRIDGE']}"
  steps %Q{ When I run `#{house}` }
end

Then(/^I should see the box's name$/) do
  steps %Q{ Then the stdout should contain "#{ENV['BOX_NAME']}" }
end

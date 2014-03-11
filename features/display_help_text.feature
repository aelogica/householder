Feature: Sysadmin reads help text
  As a sysadmin
  I want to see what householder can do for me

Scenario: Run house without arguments
  When I run `house`
  Then I should see the help text
  Then the exit status should be 0

Scenario: Run house with the help switch enabled
  When I run `house --help`
  Then I should see the help text
  Then the exit status should be 0
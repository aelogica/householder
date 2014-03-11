Feature: Sysadmin houses a box
  As a sysadmin
  I want to house a box in a remote Mac
  So that I can save money on hosting

Background:
  Given I initialize password-less SSH access

Scenario: House a box
  Given I connect to a running system interactively
  When I run the command to house the box
  And I disconnect
  Then I should see the box's name
  And the exit status should be 0

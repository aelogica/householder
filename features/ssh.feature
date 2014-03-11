Feature: Connect to a remote Mac through SSH
  As a sysadmin
  I want to SSH to a remote Mac
  So that I can remotely run commands

Background:
  Given I initialize password-less SSH access

Scenario: Login successful
  Given I connect to a running system interactively
  And I type "whoami"
  And I disconnect
  Then I should see the remote username
  And the exit status should be 0

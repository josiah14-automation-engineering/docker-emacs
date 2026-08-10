# language: en
Feature: Systems IDE Cucumber editing
  Scenario: Edit a Gherkin specification
    Given a project uses Cucumber
    When its feature file is opened
    Then the editor understands Gherkin

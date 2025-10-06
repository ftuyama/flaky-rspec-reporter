# frozen_string_literal: true

require_relative 'github_integration'
require_relative 'report_builder'

token = ENV['GITHUB_TOKEN']
repository = ENV['GITHUB_REPO_NAME']
workflow_file = ENV['GITHUB_WORKFLOW_FILE']

github = GithubIntegration.new(repo: repository, token:)
runs = github.last_workflow_runs(workflow_file:, count: 5)

all_jsons = []
runs.each do |run|
  github.artifacts_for_run(run[:id]).each do |artifact|
    next unless artifact[:name].start_with?('rspec-results')

    all_jsons.concat(github.download_artifact(artifact))
  end
end

# Aggregate tests and build a report
report = ReportBuilder.new(all_jsons).build

# Publishing the report
puts("Flaky report:\n------\n\n#{report}") # rubocop:disable Rails/Output
github.create_or_update_github_issue(report)

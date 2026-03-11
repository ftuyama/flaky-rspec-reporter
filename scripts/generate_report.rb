# frozen_string_literal: true

require_relative 'github_integration'
require_relative 'report_builder'

token = ENV['GITHUB_TOKEN']
repository = ENV['GITHUB_REPO_NAME']
workflow_file = ENV['GITHUB_WORKFLOW_FILE']

github = GithubIntegration.new(repo: repository, token:)
runs = github.last_workflow_runs(workflow_file:, count: 5)

all_run_data = []
runs.each do |run|
  branch = run[:head_branch] || run['head_branch']
  github.artifacts_for_run(run[:id]).each do |artifact|
    next unless artifact[:name].start_with?('rspec-results')

    github.download_artifact(artifact).each do |json_str|
      all_run_data << { branch: branch, json: json_str }
    end
  end
end

# Aggregate tests and build a report (only specs that failed in 2+ branches)
report = ReportBuilder.new(all_run_data).build

# Publishing the report
puts("Flaky report:\n------\n\n#{report}") # rubocop:disable Rails/Output
github.create_or_update_github_issue(report)

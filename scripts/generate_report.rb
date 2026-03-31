# frozen_string_literal: true

require_relative 'github_integration'
require_relative 'report_builder'

module FlakySpecReporter
  # Fetches workflow artifacts, builds a flaky-spec Markdown report, and updates the GitHub issue.
  class GenerateReport
    def initialize(env: ENV, github_class: GithubIntegration, report_builder_class: ReportBuilder, output: $stdout)
      @github = github_class.new(repo: env['GITHUB_REPO_NAME'], token: env['GITHUB_TOKEN'])
      @report_builder_class = report_builder_class
      @output = output
      @workflow_file = env['GITHUB_WORKFLOW_FILE']
      @runs_count = env.fetch('WORKFLOW_RUNS_COUNT', '100').to_i
    end

    def run # rubocop:disable Metrics/AbcSize
      runs = github.last_workflow_runs(workflow_file:, count: runs_count)

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

      report = report_builder_class.new(all_run_data).build

      output.puts("Flaky report:\n------\n\n#{report}")
      github.create_or_update_github_issue(report)
    end

    private

    attr_reader :github, :report_builder_class, :output, :workflow_file, :runs_count
  end
end

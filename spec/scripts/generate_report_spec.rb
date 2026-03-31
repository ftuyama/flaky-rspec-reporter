# frozen_string_literal: true

require 'rails_helper'

require Rails.root.join('scripts/generate_report')

RSpec.describe FlakySpecReporter::GenerateReport do
  describe '#run' do
    let(:output) { StringIO.new }
    let(:env) do
      {
        'GITHUB_TOKEN' => 'tok',
        'GITHUB_REPO_NAME' => 'org/repo',
        'GITHUB_WORKFLOW_FILE' => 'ci.yml',
        'WORKFLOW_RUNS_COUNT' => '5'
      }
    end
    let(:github) { instance_double(GithubIntegration) }
    let(:report_builder_instance) { instance_double(ReportBuilder, build: "REPORT\n") }
    let(:reporter) { described_class.new(env:, output:) }

    before do
      allow(GithubIntegration).to receive(:new).with(repo: 'org/repo', token: 'tok').and_return(github)
      allow(github).to receive(:last_workflow_runs).with(workflow_file: 'ci.yml', count: 5).and_return(
        [{ head_branch: 'main', id: 99 }]
      )
      allow(github).to receive(:artifacts_for_run).with(99).and_return(
        [{ id: 1, name: 'rspec-results-1', archive_download_url: 'https://api.github.com/x' }]
      )
      allow(github).to receive(:download_artifact).and_return(['{"examples":[]}'])
      allow(github).to receive(:create_or_update_github_issue)
      allow(ReportBuilder).to receive(:new).and_return(report_builder_instance)
    end

    it 'generates a flaky spec report and updates the GitHub issue' do
      reporter.run

      expect(ReportBuilder).to have_received(:new).with(
        [{ branch: 'main', json: '{"examples":[]}' }]
      )
      expect(output.string).to include('Flaky report:')
      expect(output.string).to include('REPORT')
      expect(github).to have_received(:create_or_update_github_issue).with("REPORT\n")
    end

    it 'ignores artifacts that do not start with rspec-results' do
      allow(github).to receive(:artifacts_for_run).with(99).and_return(
        [{ id: 1, name: 'other-artifact', archive_download_url: 'https://api.github.com/y' }]
      )

      reporter.run

      expect(ReportBuilder).to have_received(:new).with([])
      expect(github).not_to have_received(:download_artifact)
    end
  end
end

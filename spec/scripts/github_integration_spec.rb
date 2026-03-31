# frozen_string_literal: true

require 'rails_helper'

require Rails.root.join('scripts/github_integration')

RSpec.describe GithubIntegration do
  subject(:integration) { described_class.new(repo: 'org/repo', token: 'secret') }

  let(:client) { instance_double(Octokit::Client) }

  before do
    allow(Octokit::Client).to receive(:new).with(access_token: 'secret').and_return(client)
    allow(client).to receive(:create_issue)
    allow(client).to receive(:update_issue)
  end

  describe '#last_workflow_runs' do
    it 'returns the first count runs from completed workflow runs' do
      runs = (1..5).map { |i| { id: i, head_branch: "b#{i}" } }
      allow(client).to receive(:workflow_runs).with(
        'org/repo', 'ci.yml', status: 'completed'
      ).and_return({ workflow_runs: runs })

      result = integration.last_workflow_runs(workflow_file: 'ci.yml', count: 3)

      expect(result.size).to eq(3)
      expect(result.map { |r| r[:id] }).to eq([1, 2, 3])
    end
  end

  describe '#artifacts_for_run' do
    it 'returns artifacts from the API' do
      artifacts = [{ id: 9, name: 'rspec-results' }]
      allow(client).to receive(:workflow_run_artifacts).with('org/repo', 42).and_return({ artifacts: })

      expect(integration.artifacts_for_run(42)).to eq(artifacts)
    end
  end

  describe '#create_or_update_github_issue' do
    it 'updates an existing open issue with the same title' do
      existing = { title: 'Flaky Specs Report', number: 7 }
      allow(client).to receive(:issues).with('org/repo', state: 'open').and_return([existing])

      integration.create_or_update_github_issue('body text')

      expect(client).to have_received(:update_issue).with('org/repo', 7, body: 'body text')
      expect(client).not_to have_received(:create_issue)
    end

    it 'creates a new issue when none match' do
      allow(client).to receive(:issues).with('org/repo', state: 'open').and_return([])

      integration.create_or_update_github_issue('new body')

      expect(client).to have_received(:create_issue).with('org/repo', 'Flaky Specs Report', 'new body')
      expect(client).not_to have_received(:update_issue)
    end
  end
end

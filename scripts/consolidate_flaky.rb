#!/usr/bin/env ruby
require 'octokit'
require 'base64'
require 'json'

# Required ENV variables
repo = ENV['GITHUB_REPO_NAME']      # e.g., owner/repo
token = ENV['GITHUB_TOKEN']
workflow_file = ENV['GITHUB_WORKFLOW_FILE'] || 'Run Tests.yml'
branch = ENV['GITHUB_BRANCH'] || 'main'

client = Octokit::Client.new(access_token: token)
owner, repo_name = repo.split('/')

# 1. Fetch workflow runs
runs_resp = client.workflow_runs("#{owner}/#{repo_name}", workflow_file, branch: branch, status: 'completed')
run_ids = runs_resp[:workflow_runs].first(10).map { |r| r[:id] } # last 10 runs

artifact_contents = []

# 2. Download artifacts
run_ids.each do |run_id|
  artifacts = client.workflow_run_artifacts("#{owner}/#{repo_name}", run_id)[:artifacts]
  artifacts.each do |artifact|
    next unless artifact[:name].start_with?('rspec-results-run')

    zip_data = client.download_artifact("#{owner}/#{repo_name}", artifact[:id], archive_format: 'zip')
    # The downloaded data is base64, convert to string
    artifact_contents << Base64.decode64(zip_data)
  end
end

body = artifact_contents.join("\n\n---\n\n")
issue_title = 'Consolidated Flaky RSpec Report'

# 3. Create or update GitHub issue
issues = client.issues("#{owner}/#{repo_name}", state: 'open')
existing = issues.find { |i| i[:title] == issue_title }

if existing
  client.update_issue("#{owner}/#{repo_name}", existing[:number], body: body)
else
  client.create_issue("#{owner}/#{repo_name}", issue_title, body)
end

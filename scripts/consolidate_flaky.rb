#!/usr/bin/env ruby
require 'octokit'
require 'net/http'
require 'uri'
require 'base64'
require 'json'
require 'zip' # for reading zip files if needed
require 'tempfile'

# Required ENV variables
repo = ENV['GITHUB_REPO_NAME'] || 'ftuyama/flaky-rspec-reporter'
token = ENV['GITHUB_TOKEN']
workflow_file = ENV['GITHUB_WORKFLOW_FILE'] || 'run-tests.yml'
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

    # Fetch the artifact zip file
    uri = URI(artifact[:archive_download_url])
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "token #{token}"
    req['Accept'] = 'application/vnd.github.v3+json'

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

    # Save to temp file and extract the JSON(s) inside
    Tempfile.open(['artifact', '.zip']) do |tmp|
      tmp.binmode
      tmp.write(res.body)
      tmp.rewind

      Zip::File.open(tmp.path) do |zip_file|
        zip_file.each do |entry|
          artifact_contents << entry.get_input_stream.read if entry.name.end_with?('.json')
        end
      end
    end
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

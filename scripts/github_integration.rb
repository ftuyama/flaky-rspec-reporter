# frozen_string_literal: true

require 'octokit'
require 'zip'
require 'net/http'
require 'uri'

# Github Integration to fetch artifacts and manage issue
class GithubIntegration
  MAX_RETRY_ATTEMPTS = 2

  attr_reader :repo, :token, :client

  ARTIFACTS_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    size_in_bytes: :size,
    archive_download_url: [:archive_download_url],
    created_at: :created_at
  }

  def initialize(repo:, token:)
    @repo = repo
    @token = token
    @client = Octokit::Client.new(access_token: token)
  end

  # Get last N workflow runs for a given workflow file and branch
  def last_workflow_runs(workflow_file:, count: 10)
    with_api_retries do
      resp = client.workflow_runs(@repo, workflow_file, status: 'completed')
      resp[:workflow_runs].first(count)
    end
  end

  # List artifacts for a workflow run
  def artifacts_for_run(run_id)
    with_api_retries do
      client.workflow_run_artifacts(@repo, run_id)[:artifacts]
    end
  end

  # Download artifact and return content
  def download_artifact(artifact)
    url = artifact[:archive_download_url] or raise('Artifact missing archive_download_url')
    zip_file = "#{artifact[:name]}.zip"

    puts("Downloading #{artifact[:name]} ##{artifact[:id]}") # rubocop:disable Rails/Output
    system("wget -q -O '#{zip_file}' '#{get_redirect_url(url)}'") ||
      raise("Failed to download #{artifact[:name]}")

    extract_json_from_zip(zip_file)
  ensure
    File.delete(zip_file) if zip_file && File.exist?(zip_file)
  end

  def extract_json_from_zip(zip_file)
    Zip::File.open(zip_file) do |zip|
      zip.filter_map do |entry|
        entry.get_input_stream.read if entry.name.end_with?('.json')
      end
    end
  end

  def create_or_update_github_issue(body)
    issue_title = 'Flaky Specs Report'
    issues = @client.issues(@repo, state: 'open')
    existing = issues.find { |i| i[:title] == issue_title }

    if existing
      client.update_issue(@repo, existing[:number], body: body)
    else
      client.create_issue(@repo, issue_title, body)
    end
  end

  private

  # Follow redirect to get the actual download link
  def get_redirect_url(url)
    with_api_retries do
      uri = URI(url)
      req = Net::HTTP::Get.new(uri)
      req['Authorization'] = "token #{token}"
      req['Accept'] = 'application/vnd.github.v3+json'

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      raise('Failed to get redirect for artifact') unless res.is_a?(Net::HTTPRedirection)

      res['location']
    end
  end

  def with_api_retries(attempt: 0)
    yield
  rescue Octokit::Unauthorized, StandardError => ex
    raise ex if attempt >= MAX_RETRY_ATTEMPTS

    sleep 1
    with_api_retries(attempt: attempt + 1, &Proc.new)
  end
end

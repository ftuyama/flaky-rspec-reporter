require 'octokit'
require 'zip'
require 'net/http'
require 'uri'


class GithubIntegration
  MAX_RETRY_ATTEMPTS = 2
  RETRYABLE_ERRORS = []

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
    @owner, @repo_name = repo.split('/')
  end

  # Get last N workflow runs for a given workflow file and branch
  def last_workflow_runs(workflow_file:, branch: 'main', count: 10)
    with_api_retries do
      resp = client.workflow_runs("#{@owner}/#{@repo_name}", workflow_file, branch: branch, status: 'completed')
      resp[:workflow_runs].first(count)
    end
  end

  # List artifacts for a workflow run
  def artifacts_for_run(run_id)
    with_api_retries do
      client.workflow_run_artifacts("#{@owner}/#{@repo_name}", run_id)[:artifacts]
    end
  end

  # Download artifact and return content
  def download_artifact(artifact)
    raise "Artifact missing archive_download_url" unless artifact[:archive_download_url]

    redirect_url = get_redirect_url(artifact[:archive_download_url])
    zip_file = "#{artifact[:name]}.zip"

    # Download with wget
    puts "Downloading #{artifact[:name]} ##{artifact[:id]}"
    system("wget -q -O #{zip_file} '#{redirect_url}'") || raise("Failed to download #{artifact[:name]}")

    contents = []
    Zip::File.open(zip_file) do |zip|
      zip.each { |entry| contents << entry.get_input_stream.read if entry.name.end_with?('.json') }
    end

    File.delete(zip_file) if File.exist?(zip_file)
    contents
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

      raise "Failed to get redirect for artifact" unless res.is_a?(Net::HTTPRedirection)
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

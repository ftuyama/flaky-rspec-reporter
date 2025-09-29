require_relative 'github_integration'
require_relative 'flaky_report_builder'

token = ENV['GH_PAT'] || ENV['GITHUB_TOKEN']
github = GithubIntegration.new(repo: "ftuyama/flaky-rspec-reporter", token:)
runs = github.last_workflow_runs(workflow_file: "run-tests.yml", branch: "main", count: 3)

all_jsons = []
runs.each do |run|
  github.artifacts_for_run(run[:id]).each do |artifact|
    next unless artifact[:name].start_with?('rspec-results-run')
    all_jsons.concat(github.download_artifact(artifact))
  end
end

# Aggregate and create/update issue
builder = FlakyReportBuilder.new(all_jsons)
body = builder.build
issue_title = "Consolidated Flaky RSpec Report"
client = Octokit::Client.new(access_token: token)
issues = client.issues("ftuyama/flaky-rspec-reporter", state: 'open')
existing = issues.find { |i| i[:title] == issue_title }

puts "Flaky report:\n------\n\n#{body}"
if existing
  client.update_issue("ftuyama/flaky-rspec-reporter", existing[:number], body: body)
else
  client.create_issue("ftuyama/flaky-rspec-reporter", issue_title, body)
end

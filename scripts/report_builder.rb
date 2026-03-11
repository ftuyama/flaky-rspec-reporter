# frozen_string_literal: false

# Builds the flaky spec report (md format)
# Only includes specs that failed in at least two different branches.
class ReportBuilder
  attr_reader :run_data

  def initialize(run_data)
    # run_data: array of { branch:, json: } (branch from workflow run, json string)
    @run_data = run_data
  end

  def build
    all_runs = parse_jsons
    flaky_specs = detect_flaky(all_runs)
    generate_markdown(flaky_specs, all_runs)
  end

  private

  def parse_jsons
    run_data.map do |entry|
      branch = entry[:branch]
      json_str = entry[:json]
      parsed = JSON.parse(json_str)
      parsed['branch'] = branch
      parsed
    rescue JSON::ParserError => e
      warn("Failed to parse JSON: #{e.message}")
      nil
    end.compact
  end

  # Flatten examples with run metadata (including branch)
  def examples_with_run_data(all_runs)
    all_runs.flat_map do |run|
      run['examples'].map do |ex|
        ex.merge(
          'run_start_time' => run['run_start_time'],
          'branch' => run['branch']
        )
      end
    end
  end

  def detect_flaky(all_runs)
    examples_with_run_data(all_runs)
      .group_by { |ex| [ex['file_path'], ex['line_number'], ex['full_description']] }
      .map { |key, runs| build_flaky_spec(key, runs) }
      .compact
      .sort_by { |h| -h[:rate] }
  end

  def build_flaky_spec((file, line, description), runs)
    total = runs.size
    failure_runs = runs.select { |ex| !%w[passed pending].include?(ex['status']) }
    return if failure_runs.empty?

    branches_with_failures = failure_runs.map { |ex| ex['branch'] }.compact.uniq
    return if branches_with_failures.size < 2

    failures = failure_runs.size
    {
      file_line: "#{file}:#{line}",
      description:,
      failures:,
      total:,
      rate: (failures.to_f / total * 100).round(2)
    }
  end

  def generate_markdown(flaky_specs, all_runs)
    return 'No flaky specs detected across runs.' if flaky_specs.empty?

    header = <<~MD
      # Flaky RSpec Report

      Generated at: #{Time.now.utc}

      Number of runs processed: #{all_runs.size}
      First run date: #{all_runs.map { |r| r['run_start_time'] }.min}

      | File:Line | Flaky Rate (%) | Failures / Total | Spec Description |
      |-----------|----------------|------------------|------------------|
    MD

    rows = flaky_specs.map do |spec|
      "| `#{spec[:file_line]}` | #{spec[:rate]} | #{spec[:failures]}/#{spec[:total]} | #{spec[:description]} |"
    end

    "#{header}#{rows.join("\n")}\n"
  end
end

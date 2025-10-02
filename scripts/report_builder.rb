# frozen_string_literal: false

# Builds the flaky spec report (md format)
class ReportBuilder
  attr_reader :json_contents

  def initialize(json_contents)
    @json_contents = json_contents
  end

  def build
    all_examples = parse_jsons
    flaky_specs = detect_flaky(all_examples)
    generate_markdown(flaky_specs, all_examples)
  end

  private

  def parse_jsons
    json_contents.map do |json_str|
      JSON.parse(json_str)
    rescue JSON::ParserError => e
      warn("Failed to parse JSON: #{e.message}")
      nil
    end.compact
  end

  # Flatten examples with run metadata
  def examples_with_run_data(all_runs)
    all_runs.flat_map do |run|
      run['examples'].map do |ex|
        ex.merge('run_start_time' => run['run_start_time'])
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
    failures = runs.count { |ex| ex['status'] != 'passed' }
    return if failures.zero?

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

      | File:Line | Spec Description | Failures / Total | Flaky Rate (%) |
      |-----------|-----------------|------------------|----------------|
    MD

    rows = flaky_specs.map do |spec|
      "| `#{spec[:file_line]}` | #{spec[:description]} | #{spec[:failures]}/#{spec[:total]} | #{spec[:rate]} |"
    end

    "#{header}#{rows.join("\n")}\n"
  end
end

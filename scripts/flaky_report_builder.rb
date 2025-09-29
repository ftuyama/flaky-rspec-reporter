class FlakyReportBuilder
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
      warn "Failed to parse JSON: #{e.message}"
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
    examples = examples_with_run_data(all_runs)
    spec_groups = examples.group_by { |ex| [ex['file_path'], ex['line_number'], ex['full_description']] }

    flaky = {}

    spec_groups.each do |key, runs|
      total = runs.size
      failed = runs.count { |ex| ex['status'] != 'passed' }
      next if failed == 0

      flaky[key] = {
        file_line: "#{key[0]}:#{key[1]}",
        description: key[2],
        failures: failed,
        total: total,
        rate: (failed.to_f / total * 100).round(2)
      }
    end

    flaky.values.sort_by { |h| -h[:rate] }
  end

  def generate_markdown(flaky_specs, all_runs)
    return "No flaky specs detected across runs." if flaky_specs.empty?

    num_runs = all_runs.size
    first_run_date = all_runs.map { |r| r['run_start_time'] }.min

    md = "# Flaky RSpec Report\n\n"
    md << "Generated at: #{Time.now.utc}\n\n"
    md << "Number of runs processed: #{num_runs}  \n"
    md << "First run date: #{first_run_date}\n\n"

    md << "| File:Line | Spec Description | Failures / Total | Flaky Rate (%) |\n"
    md << "|-----------|-----------------|----------------|----------------|\n"

    flaky_specs.each do |spec|
      md << "| `#{spec[:file_line]}` | #{spec[:description]} | #{spec[:failures]}/#{spec[:total]} | #{spec[:rate]} |\n"
    end

    md
  end
end

#!/usr/bin/env ruby

require 'json'
require 'fileutils'

class FlakyReportAggregator
  def initialize
    @artifacts_dir = 'artifacts'
    @reports = []
    @flaky_tests = {}
    @summary = {
      total_runs: 0,
      total_examples: 0,
      flaky_examples: [],
      most_flaky: nil,
      summary_generated_at: Time.now.iso8601
    }
  end

  def aggregate
    load_reports
    analyze_flakiness
    generate_summary
  end

  private

  def load_reports
    report_files = Dir.glob(File.join(@artifacts_dir, '**', 'flaky-rspec.json'))
    
    report_files.each do |file|
      begin
        content = File.read(file)
        report = JSON.parse(content)
        @reports << report
        @summary[:total_runs] += 1
        @summary[:total_examples] += report['total_examples'] || 0
      rescue JSON::ParserError => e
        puts "Warning: Could not parse #{file}: #{e.message}"
      rescue Errno::ENOENT => e
        puts "Warning: File not found #{file}: #{e.message}"
      end
    end

    puts "Loaded #{@reports.size} reports from #{report_files.size} files"
  end

  def analyze_flakiness
    @reports.each do |report|
      examples = report['examples'] || []
      
      examples.each do |example|
        key = example['full_description']
        
        @flaky_tests[key] ||= {
          description: example['description'],
          full_description: example['full_description'],
          file_path: example['file_path'],
          line_number: example['line_number'],
          total_runs: 0,
          failures: 0,
          passes: 0,
          failure_rate: 0.0,
          last_failure: nil,
          failure_messages: []
        }

        @flaky_tests[key][:total_runs] += 1

        case example['status']
        when 'failed'
          @flaky_tests[key][:failures] += 1
          @flaky_tests[key][:last_failure] = example['timestamp']
          
          if example['exception'] && example['exception']['message']
            message = example['exception']['message']
            @flaky_tests[key][:failure_messages] << message unless @flaky_tests[key][:failure_messages].include?(message)
          end
        when 'passed'
          @flaky_tests[key][:passes] += 1
        end
      end
    end

    # Calculate failure rates and identify flaky tests
    @flaky_tests.each do |key, test_data|
      if test_data[:total_runs] > 0
        test_data[:failure_rate] = (test_data[:failures].to_f / test_data[:total_runs] * 100).round(2)
        
        # Consider a test flaky if it has both failures and passes
        if test_data[:failures] > 0 && test_data[:passes] > 0
          @summary[:flaky_examples] << test_data
        end
      end
    end

    # Sort by failure rate (most flaky first)
    @summary[:flaky_examples].sort_by! { |test| -test[:failure_rate] }
    @summary[:most_flaky] = @summary[:flaky_examples].first
  end

  def generate_summary
    puts "\n" + "="*80
    puts "FLAKY RSPEC REPORTER - SUMMARY REPORT"
    puts "="*80
    puts "Generated at: #{@summary[:summary_generated_at]}"
    puts "Total test runs analyzed: #{@summary[:total_runs]}"
    puts "Total examples across all runs: #{@summary[:total_examples]}"
    puts "Number of flaky tests identified: #{@summary[:flaky_examples].size}"
    
    if @summary[:flaky_examples].any?
      puts "\n" + "-"*80
      puts "FLAKY TESTS DETECTED:"
      puts "-"*80
      
      @summary[:flaky_examples].each_with_index do |test, index|
        puts "\n#{index + 1}. #{test[:full_description]}"
        puts "   File: #{test[:file_path]}:#{test[:line_number]}"
        puts "   Failure Rate: #{test[:failure_rate]}% (#{test[:failures]}/#{test[:total_runs]} runs failed)"
        puts "   Last Failure: #{test[:last_failure]}"
        
        if test[:failure_messages].any?
          puts "   Common Failure Messages:"
          test[:failure_messages].first(3).each do |msg|
            puts "     - #{msg.gsub(/\n/, ' ').strip[0..100]}#{'...' if msg.length > 100}"
          end
        end
      end

      if @summary[:most_flaky]
        puts "\n" + "-"*80
        puts "MOST FLAKY TEST:"
        puts "-"*80
        most_flaky = @summary[:most_flaky]
        puts "#{most_flaky[:full_description]}"
        puts "Failure Rate: #{most_flaky[:failure_rate]}%"
        puts "File: #{most_flaky[:file_path]}:#{most_flaky[:line_number]}"
      end
    else
      puts "\n🎉 No flaky tests detected! All tests are consistently passing or failing."
    end

    puts "\n" + "="*80
    puts "END OF REPORT"
    puts "="*80
  end
end

# Check if artifacts directory exists
unless Dir.exist?('artifacts')
  puts "Creating artifacts directory for demo purposes..."
  FileUtils.mkdir_p('artifacts')
  
  # Create a sample report for demonstration
  sample_report = {
    "total_examples" => 10,
    "run_start_time" => (Time.now - 3600).iso8601,
    "run_end_time" => Time.now.iso8601,
    "duration" => 45.2,
    "examples" => [
      {
        "description" => "generates a number within expected range",
        "full_description" => "Calculator.random_calculation generates a number within expected range",
        "file_path" => "./spec/models/calculator_spec.rb",
        "line_number" => 25,
        "status" => "failed",
        "run_time" => 0.001,
        "timestamp" => Time.now.iso8601,
        "exception" => {
          "class" => "RSpec::Expectations::ExpectationNotMetError",
          "message" => "expected: 50, got: 73"
        }
      }
    ]
  }
  
  File.write('artifacts/flaky-rspec.json', JSON.pretty_generate(sample_report))
  puts "Created sample report at artifacts/flaky-rspec.json"
end

# Run the aggregator
aggregator = FlakyReportAggregator.new
aggregator.aggregate
require 'json'
require 'rspec/core'
require 'rspec/core/formatters/base_formatter'

module RSpec
  module Flaky
    class Formatter < RSpec::Core::Formatters::BaseFormatter
      RSpec::Core::Formatters.register self, :start, :example_started, :example_passed, :example_failed, :example_pending, :stop

      def initialize(output)
        super
        @results = []
        @run_start_time = nil
        @run_end_time = nil
      end

      def start(notification)
        @run_start_time = Time.now
        @total_examples = notification.count
      end

      def example_started(notification)
        @example_start_time = Time.now
      end

      def example_passed(notification)
        record_example(notification, 'passed')
      end

      def example_failed(notification)
        record_example(notification, 'failed')
      end

      def example_pending(notification)
        record_example(notification, 'pending')
      end

      def stop(notification)
        @run_end_time = Time.now
        output_results
      end

      private

      def record_example(notification, status)
        example = notification.example
        execution_time = Time.now - @example_start_time

        result = {
          description: example.description,
          full_description: example.full_description,
          file_path: example.metadata[:file_path],
          line_number: example.metadata[:line_number],
          status: status,
          run_time: execution_time,
          timestamp: Time.now.iso8601,
          exception: status == 'failed' ? extract_exception_info(example.exception) : nil
        }

        @results << result
      end

      def extract_exception_info(exception)
        return nil unless exception

        {
          class: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace&.first(10)
        }
      end

      def output_results
        summary = {
          total_examples: @total_examples,
          run_start_time: @run_start_time.iso8601,
          run_end_time: @run_end_time.iso8601,
          duration: @run_end_time - @run_start_time,
          examples: @results
        }

        output.puts JSON.pretty_generate(summary)
      end
    end
  end
end
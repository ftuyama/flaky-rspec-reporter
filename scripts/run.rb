# frozen_string_literal: true

# Entry point for CI (e.g. flaky-specs-reporter workflow). Loads the reporter and runs it once.
require_relative 'generate_report'

FlakySpecReporter::GenerateReport.new.run

# frozen_string_literal: true

require 'rails_helper'

require Rails.root.join('scripts/report_builder')

RSpec.describe ReportBuilder do
  include ActiveSupport::Testing::TimeHelpers

  describe '#build' do
    let(:flaky_spec_on_single_branch) do
      json = {
        'run_start_time' => '2025-01-01 12:00:00 UTC',
        'examples' => [
          example_hash('spec/a_spec.rb', 10, 'fails', 'failed')
        ]
      }.to_json

      [
        { branch: 'main', json: },
        { branch: 'main', json: }
      ]
    end

    let(:flaky_spec_on_two_branches) do
      ex = example_hash('spec/flaky_spec.rb', 5, 'unstable example', 'failed')
      passed = example_hash('spec/flaky_spec.rb', 5, 'unstable example', 'passed')
      [
        {
          branch: 'main',
          json: { 'run_start_time' => '2025-01-02 12:00:00 UTC', 'examples' => [ex, passed] }.to_json
        },
        {
          branch: 'feature',
          json: { 'run_start_time' => '2025-01-03 12:00:00 UTC', 'examples' => [ex] }.to_json
        }
      ]
    end

    let(:flaky_spec_with_pending) do
      fail_ex = example_hash('spec/x_spec.rb', 1, 'x', 'failed')
      pending_ex = example_hash('spec/x_spec.rb', 1, 'x', 'pending')
      json = {
        'run_start_time' => '2025-01-01 00:00:00 UTC',
        'examples' => [fail_ex, pending_ex]
      }.to_json

      [
        { branch: 'a', json: },
        { branch: 'b', json: }
      ]
    end

    around do |example|
      travel_to(Time.utc(2025, 6, 15, 10, 0, 0)) { example.run }
    end

    it 'returns no-flaky message when run_data is empty' do
      expect(described_class.new([]).build).to eq('No flaky specs detected across runs.')
    end

    it 'skips invalid JSON and warns' do
      result = nil
      expect do
        result = described_class.new([{ branch: 'main', json: 'not json {' }]).build
      end.to output(/Failed to parse JSON/).to_stderr

      expect(result).to eq('No flaky specs detected across runs.')
    end

    it 'omits spec that only failed on a single branch' do
      report = described_class.new(flaky_spec_on_single_branch).build

      expect(report).to eq('No flaky specs detected across runs.')
    end

    it 'includes spec that failed on two different branches' do
      report = described_class.new(flaky_spec_on_two_branches).build

      expect(report).to include(
        '# Flaky RSpec Report',
        'Number of runs processed: 2',
        'Generated at: 2025-06-15 10:00 UTC',
        'First run date: 2025-01-02 12:00 UTC',
        '`spec/flaky_spec.rb:5`',
        '66.67',
        '2/3',
        'unstable example'
      )
    end

    it 'treats pending like passed for failure counting' do
      report = described_class.new(flaky_spec_with_pending).build

      expect(report).to include(
        '# Flaky RSpec Report',
        'Number of runs processed: 2',
        'Generated at: 2025-06-15 10:00 UTC',
        'First run date: 2025-01-01 00:00 UTC',
        '50.0',
        '2/4',
        'x'
      )
    end
  end

  def example_hash(file_path, line_number, description, status)
    {
      'file_path' => file_path,
      'line_number' => line_number,
      'full_description' => description,
      'status' => status
    }
  end
end

require 'rails_helper'

RSpec.describe Calculator, type: :model do
  describe '.add' do
    it 'adds two numbers correctly' do
      expect(Calculator.add(2, 3)).to eq(5)
    end

    it 'handles negative numbers' do
      expect(Calculator.add(-1, 1)).to eq(0)
    end
  end

  describe '.multiply' do
    it 'multiplies two numbers correctly' do
      expect(Calculator.multiply(3, 4)).to eq(12)
    end
  end

  describe '.divide' do
    it 'divides two numbers correctly' do
      expect(Calculator.divide(10, 2)).to eq(5)
    end

    it 'raises error when dividing by zero' do
      expect { Calculator.divide(10, 0) }.to raise_error(ArgumentError, "Cannot divide by zero")
    end
  end

  # FLAKY TEST 1: Random number generation
  describe '.random_calculation' do
    it 'generates a number within expected range' do
      result = Calculator.random_calculation
      # This is flaky because it relies on random generation
      # Sometimes it might be exactly 50, sometimes not
      expect(result).to be_between(1, 100)
      expect(result).to eq(50) # This will randomly fail
    end
  end

  # FLAKY TEST 2: Time-dependent test
  describe 'time-dependent behavior' do
    it 'should process within a specific timeframe' do
      start_time = Time.now
      Calculator.add(1, 1)
      end_time = Time.now
      
      # This is flaky because execution time can vary
      expect(end_time - start_time).to be < 0.001 # Very tight timing constraint
    end
  end

  # FLAKY TEST 3: Method that randomly fails
  describe '.flaky_method' do
    it 'should always return success' do
      # This method randomly raises an exception about 30% of the time
      expect(Calculator.flaky_method).to eq("Success")
    end
  end
end
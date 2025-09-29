class Calculator
  def self.add(a, b)
    a + b
  end

  def self.multiply(a, b)
    a * b
  end

  def self.divide(a, b)
    raise ArgumentError, "Cannot divide by zero" if b == 0
    a / b
  end

  def self.random_calculation
    # This method is intentionally flaky for testing
    rand(1..100)
  end

  def self.flaky_method
    # Randomly fails or succeeds
    if rand < 0.3
      raise StandardError, "Random failure"
    end
    "Success"
  end
end
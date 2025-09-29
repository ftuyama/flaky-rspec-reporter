# Flaky RSpec Reporter

A Rails 8 demo application that demonstrates automated detection and reporting of flaky RSpec tests using custom formatters and GitHub Actions.

## Features

- **Custom RSpec Formatter**: Captures detailed test execution data in JSON format
- **Flaky Test Detection**: Identifies tests that exhibit inconsistent behavior across multiple runs
- **GitHub Actions Integration**: Automated test execution and flaky test reporting
- **Persistent Issue Tracking**: Automatically creates GitHub issues for detected flaky tests
- **Comprehensive Reporting**: Detailed summaries with failure rates and common error patterns

## Setup

1. Clone the repository:
```bash
git clone https://github.com/ftuyama/flaky-rspec-reporter.git
cd flaky-rspec-reporter
```

2. Install dependencies:
```bash
bundle install
```

3. Set up the database:
```bash
rails db:create db:migrate
```

## Usage

### Running Tests with Flaky Reporter

```bash
# Run tests with the custom flaky formatter
bundle exec rspec --format RSpec::Flaky::Formatter --out flaky-rspec.json

# View the generated JSON report
cat flaky-rspec.json
```

### Aggregating Reports

```bash
# Aggregate multiple test run reports
ruby scripts/aggregate_flaky.rb > flaky_summary.txt

# View the summary
cat flaky_summary.txt
```

### GitHub Actions Workflow

The repository includes a comprehensive GitHub Actions workflow (`.github/workflows/flaky-rspec.yml`) that:

1. **Runs tests multiple times** to increase the likelihood of detecting flaky behavior
2. **Uploads test artifacts** for analysis
3. **Aggregates results** across all test runs
4. **Creates GitHub issues** for persistent tracking of flaky tests
5. **Comments on PRs** with flaky test detection results

#### Scheduled Runs

The workflow runs automatically:
- On every push to `main` or `develop` branches
- On pull requests to `main`
- Daily at 2 AM UTC via cron schedule
- Can be triggered manually

## Demo Tests

The application includes 10 test examples:
- **7 stable tests**: Consistently pass or fail
- **3 flaky tests**: Demonstrate different types of flaky behavior:
  - Random number assertion failures
  - Timing-dependent test failures  
  - Randomly failing methods

## Flaky Test Categories

The reporter identifies various types of flaky tests:

1. **Random Data Dependencies**: Tests that fail due to random number generation
2. **Timing Issues**: Tests with tight timing constraints that may fail under load
3. **External Dependencies**: Tests that rely on external services or network conditions
4. **Race Conditions**: Tests that depend on execution order or threading

## Report Format

The JSON reports include:
- Test descriptions and file locations
- Execution times and timestamps
- Success/failure status
- Exception details for failures
- Overall run statistics

The aggregated summary provides:
- Failure rates for each test
- Most problematic flaky tests
- Common failure patterns
- Historical trend data

## Issue Tracking

Flaky tests are automatically tracked via GitHub issues with:
- **Labels**: `flaky-tests`, `bug`, `automated`
- **Regular Updates**: New data appended to existing issues
- **Actionable Information**: Links to test runs and specific failure details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

This project is available as open source under the terms of the MIT License.

# Flaky RSpec Reporter

Detects and reports flaky RSpec tests across workflow runs. A spec is only reported if it failed in **two different branches**. Reports are published as a GitHub issue.

**Logic lives in:** `.github/workflows/`, `lib/`, `scripts/`.

---

## Install in your repository

### 1. Copy the code

Add these into your repo (same layout as this project):

- **`lib/rspec/flaky/formatter.rb`** — RSpec formatter that writes JSON per run
- **`scripts/generate_report.rb`** — entrypoint for the report job
- **`scripts/report_builder.rb`** — aggregates runs and builds markdown
- **`scripts/github_integration.rb`** — fetches artifacts and creates/updates the issue

### 2. Load the formatter

In `spec/spec_helper.rb` (or equivalent):

```ruby
require_relative '../lib/rspec/flaky/formatter'
```

### 3. Add the workflows

**`.github/workflows/tests.yml`** (or reuse your existing test workflow):

- Run RSpec with the flaky formatter and write JSON to a folder, e.g.:
  ```yaml
  - run: |
      bundle exec rspec --format RSpec::Flaky::Formatter --out artifacts/flaky-rspec-${{ matrix.run }}.json
    continue-on-error: true
  ```
- Upload that folder as an artifact (e.g. `actions/upload-artifact@v4`) with a name that starts with `rspec-results` so the reporter can find it.

**`.github/workflows/flaky-specs-reporter.yml`**:

Set `GITHUB_WORKFLOW_FILE` to the **filename** of the workflow that runs RSpec and uploads the `rspec-results-*` artifacts (e.g. `tests.yml`).

---

## Manual run

1. In your repo on GitHub: **Actions** → select **Flaky Specs Reporter**.
2. Click **Run workflow** and run it on the default branch (or choose a branch).
3. The job fetches artifacts from the last 5 runs of the workflow named in `GITHUB_WORKFLOW_FILE`, aggregates by branch, and creates or updates the **Flaky Specs Report** issue.

You can also run the script locally (requires a GitHub token with `actions: read`, `issues: write`):

```bash
GITHUB_TOKEN=ghp_xxx GITHUB_REPO_NAME=owner/repo GITHUB_WORKFLOW_FILE=tests.yml ruby scripts/generate_report.rb
```

---

## License

MIT

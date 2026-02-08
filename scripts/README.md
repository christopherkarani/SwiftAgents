# Swarm Scripts

This directory contains utility scripts for development, testing, and CI/CD automation.

## Available Scripts

### generate-coverage-report.sh

Generates comprehensive code coverage reports for the Swarm framework.

**Usage:**
```bash
./scripts/generate-coverage-report.sh
```

**What it does:**
1. Runs Swift tests with code coverage enabled
2. Generates multiple report formats:
   - HTML (interactive, detailed)
   - JSON (machine-readable)
   - lcov (compatible with third-party tools)
   - Text (console-friendly summary)
3. Checks coverage against minimum threshold (70% by default)
4. Saves all reports to `.build/coverage/`

**Output:**
- `.build/coverage/html/index.html` - Interactive HTML report
- `.build/coverage/coverage.json` - JSON format
- `.build/coverage/coverage.lcov` - lcov format for Codecov/Coveralls
- `.build/coverage/coverage-summary.txt` - Text summary

**View HTML Report:**
```bash
open .build/coverage/html/index.html
```

**Configuration:**
Edit the `MIN_COVERAGE` variable in the script to change the threshold (default: 70%).

## CI Integration

See [docs/CI-COVERAGE-SETUP.md](/docs/CI-COVERAGE-SETUP.md) for instructions on integrating coverage reporting into GitHub Actions.

## Requirements

- macOS with Xcode Command Line Tools
- Swift 6.2 or later
- bc (for coverage threshold calculation)

## Adding New Scripts

When adding new scripts to this directory:

1. Use descriptive names: `action-what-it-does.sh`
2. Make scripts executable: `chmod +x scripts/your-script.sh`
3. Add proper documentation headers in the script
4. Document usage in this README
5. Add to .gitignore if the script generates output files

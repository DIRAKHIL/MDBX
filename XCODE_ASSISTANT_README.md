# Xcode Assistant

This tool helps you automatically find and fix common issues in Swift code for your Xcode projects.

## Features

- **Automatic Issue Detection**: Finds common Swift issues like:
  - Deprecated API usage
  - SwiftUI buildExpression errors
  - Sendable conformance issues
  - And more...

- **Suggested Fixes**: Provides specific code changes to fix each issue

- **Interactive Fixing**: Fix issues one by one or all at once

- **Reporting**: Generate detailed reports of all issues found

## How to Use

### 1. Analyze Your Project

```bash
./xcode_helper.sh analyze
```

This will scan your project for potential issues and display a summary.

### 2. Fix Issues Interactively

```bash
./xcode_helper.sh fix
```

This will show you each issue and let you decide whether to apply the suggested fix.

### 3. Fix All Issues Automatically

```bash
./xcode_helper.sh fix-all
```

This will attempt to fix all detected issues automatically.

### 4. Generate a Detailed Report

```bash
./xcode_helper.sh report
```

This will generate a detailed JSON report of all issues found.

### 5. Commit Your Changes

```bash
./xcode_helper.sh commit
```

This will commit all fixes to git with an appropriate commit message.

## Integration with Your Workflow

### Regular Maintenance

Run this tool regularly to keep your codebase up to date with the latest Swift best practices.

### CI/CD Integration

You can integrate this tool into your CI/CD pipeline to automatically detect issues in pull requests.

### Pre-commit Hook

Set up a pre-commit hook to run this tool before committing changes.

## Extending the Tool

The `xcode_assistant.py` script can be extended to detect additional issues:

1. Add new check methods in the `XcodeAssistant` class
2. Add corresponding fix methods
3. Update the `analyze_file` method to call your new checks

## Troubleshooting

If you encounter any issues:

1. Make sure both scripts are executable (`chmod +x script_name`)
2. Ensure you're running the scripts from the correct directory
3. Check that the project path in `xcode_helper.sh` is correct

## Next Steps

To further automate your development process:

1. Set up GitHub Actions to run this tool automatically
2. Create a webhook that triggers when new issues are found
3. Develop a custom Xcode extension that integrates with this tool
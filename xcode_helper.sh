#!/bin/bash

# Xcode Helper Script
# This script helps automate finding and fixing common Swift issues

PROJECT_PATH="/workspace/MDBX"
SCRIPT_PATH="/workspace/xcode_assistant.py"

# Make the Python script executable
chmod +x "$SCRIPT_PATH"

# Function to display help
show_help() {
  echo "Xcode Helper - Automate finding and fixing Swift issues"
  echo ""
  echo "Usage:"
  echo "  ./xcode_helper.sh [command]"
  echo ""
  echo "Commands:"
  echo "  analyze     - Find potential issues in the project"
  echo "  fix         - Interactively fix issues one by one"
  echo "  fix-all     - Attempt to fix all issues automatically"
  echo "  report      - Generate a detailed JSON report of issues"
  echo "  commit      - Commit fixes to git with an appropriate message"
  echo "  help        - Show this help message"
  echo ""
}

# Check if a command was provided
if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

# Process commands
case "$1" in
  analyze)
    echo "Analyzing Swift code for issues..."
    python3 "$SCRIPT_PATH" "$PROJECT_PATH" --analyze
    ;;
    
  fix)
    echo "Finding issues and suggesting fixes..."
    python3 "$SCRIPT_PATH" "$PROJECT_PATH"
    
    echo ""
    read -p "Enter the issue number to fix (or 'q' to quit): " issue_num
    
    if [ "$issue_num" != "q" ]; then
      python3 "$SCRIPT_PATH" "$PROJECT_PATH" --fix "$issue_num"
    fi
    ;;
    
  fix-all)
    echo "Attempting to fix all issues..."
    python3 "$SCRIPT_PATH" "$PROJECT_PATH" --fix-all
    ;;
    
  report)
    echo "Generating detailed report..."
    python3 "$SCRIPT_PATH" "$PROJECT_PATH" --report
    ;;
    
  commit)
    echo "Committing fixes to git..."
    cd "$PROJECT_PATH"
    git add .
    git commit -m "Fix Swift issues detected by Xcode Assistant"
    git push origin main
    echo "Changes committed and pushed to main branch"
    ;;
    
  help|*)
    show_help
    ;;
esac

exit 0
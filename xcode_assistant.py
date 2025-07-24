#!/usr/bin/env python3
"""
Xcode Assistant - A tool to help find and fix common Swift issues
"""

import os
import re
import sys
import json
import subprocess
import argparse
from pathlib import Path

class XcodeAssistant:
    def __init__(self, project_path):
        self.project_path = Path(project_path)
        self.issues = []
        
    def find_swift_files(self):
        """Find all Swift files in the project"""
        swift_files = []
        for root, _, files in os.walk(self.project_path):
            for file in files:
                if file.endswith('.swift'):
                    swift_files.append(os.path.join(root, file))
        return swift_files
    
    def analyze_file(self, file_path):
        """Analyze a Swift file for common issues"""
        with open(file_path, 'r') as f:
            content = f.read()
            
        file_issues = []
        
        # Check for buildExpression issues
        buildexp_issues = self.check_build_expression(content, file_path)
        file_issues.extend(buildexp_issues)
        
        # Check for deprecated API usage
        deprecated_issues = self.check_deprecated_apis(content, file_path)
        file_issues.extend(deprecated_issues)
        
        # Check for Sendable conformance issues
        sendable_issues = self.check_sendable_conformance(content, file_path)
        file_issues.extend(sendable_issues)
        
        return file_issues
    
    def check_build_expression(self, content, file_path):
        """Check for potential buildExpression issues in SwiftUI code"""
        issues = []
        
        # Look for VStack with spacing parameter
        vstack_pattern = r'VStack\(spacing:.*\)'
        matches = re.finditer(vstack_pattern, content)
        
        for match in matches:
            issues.append({
                'file': file_path,
                'line': content[:match.start()].count('\n') + 1,
                'type': 'buildExpression',
                'message': 'Potential buildExpression issue with VStack spacing parameter',
                'suggestion': 'Replace with VStack {} and explicit Spacer().frame(height: X) elements'
            })
            
        # Look for conditional expressions in Text interpolation
        text_interp_pattern = r'Text\(".*\\\(.*\?.*:.*\).*"\)'
        matches = re.finditer(text_interp_pattern, content)
        
        for match in matches:
            issues.append({
                'file': file_path,
                'line': content[:match.start()].count('\n') + 1,
                'type': 'buildExpression',
                'message': 'Potential buildExpression issue with conditional expression in Text interpolation',
                'suggestion': 'Extract the conditional expression to a separate variable before using in Text'
            })
            
        return issues
    
    def check_deprecated_apis(self, content, file_path):
        """Check for common deprecated APIs in Swift"""
        issues = []
        
        deprecated_apis = [
            (r'AVAsset\(url:', 'AVURLAsset(url:'),
            (r'\.duration\s', 'asset.load(.duration)'),
            (r'\.tracks\(withMediaType:', 'asset.loadTracks(withMediaType:'),
            (r'\.nominalFrameRate', 'videoTrack.load(.nominalFrameRate)'),
            (r'\.naturalSize', 'videoTrack.load(.naturalSize)'),
            (r'copyCGImage\(at:', 'generateCGImageAsynchronously(for:'),
            (r'init\(url:\)', 'AVURLAsset(url:)'),
        ]
        
        for pattern, replacement in deprecated_apis:
            matches = re.finditer(pattern, content)
            for match in matches:
                issues.append({
                    'file': file_path,
                    'line': content[:match.start()].count('\n') + 1,
                    'type': 'deprecated_api',
                    'message': f'Potential deprecated API usage: {match.group(0)}',
                    'suggestion': f'Consider using {replacement} instead'
                })
                
        return issues
    
    def check_sendable_conformance(self, content, file_path):
        """Check for potential Sendable conformance issues"""
        issues = []
        
        # Look for classes used in async contexts
        class_pattern = r'class\s+(\w+)'
        class_matches = re.finditer(class_pattern, content)
        
        for class_match in class_matches:
            class_name = class_match.group(1)
            # Check if class is used in async/Task context but doesn't conform to Sendable
            if 'Task' in content or 'async' in content:
                if f': Sendable' not in content and '@unchecked Sendable' not in content:
                    issues.append({
                        'file': file_path,
                        'line': content[:class_match.start()].count('\n') + 1,
                        'type': 'sendable_conformance',
                        'message': f'Class {class_name} might need Sendable conformance for use in async contexts',
                        'suggestion': f'Add ": @unchecked Sendable" to class definition or make class thread-safe'
                    })
                    
        return issues
    
    def analyze_project(self):
        """Analyze the entire project for issues"""
        swift_files = self.find_swift_files()
        for file in swift_files:
            file_issues = self.analyze_file(file)
            self.issues.extend(file_issues)
        
        return self.issues
    
    def generate_report(self):
        """Generate a JSON report of all issues"""
        return json.dumps(self.issues, indent=2)
    
    def suggest_fixes(self, issue_index=None):
        """Generate suggested fixes for issues"""
        if issue_index is not None:
            if 0 <= issue_index < len(self.issues):
                return self.generate_fix(self.issues[issue_index])
            else:
                return "Invalid issue index"
        
        fixes = []
        for issue in self.issues:
            fixes.append(self.generate_fix(issue))
        
        return fixes
    
    def generate_fix(self, issue):
        """Generate a specific fix for an issue"""
        if issue['type'] == 'buildExpression':
            return self.fix_build_expression(issue)
        elif issue['type'] == 'deprecated_api':
            return self.fix_deprecated_api(issue)
        elif issue['type'] == 'sendable_conformance':
            return self.fix_sendable_conformance(issue)
        else:
            return f"No automatic fix available for issue type: {issue['type']}"
    
    def fix_build_expression(self, issue):
        """Generate a fix for buildExpression issues"""
        file_path = issue['file']
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        line_num = issue['line'] - 1
        line = lines[line_num]
        
        if 'VStack(spacing:' in line:
            # Extract the spacing value
            spacing_match = re.search(r'spacing:\s*(\d+)', line)
            spacing = spacing_match.group(1) if spacing_match else '20'
            
            # Replace with VStack and explicit spacer
            indent = re.match(r'^\s*', line).group(0)
            new_line = f"{indent}VStack {{\n"
            new_line += f"{indent}    Spacer().frame(height: {spacing})\n"
            
            return {
                'file': file_path,
                'line': line_num + 1,
                'original': line.strip(),
                'replacement': new_line.strip(),
                'message': f"Replace VStack(spacing: {spacing}) with VStack and explicit Spacer"
            }
        
        elif 'Text(' in line and '\\(' in line and '?' in line:
            # Extract the conditional expression
            conditional_match = re.search(r'\\((.+?\?.+?:.+?)\\)', line)
            if conditional_match:
                conditional_expr = conditional_match.group(1)
                indent = re.match(r'^\s*', line).group(0)
                
                # Create a variable for the conditional expression
                var_name = 'computed_value'
                new_lines = f"{indent}let {var_name} = {conditional_expr}\n"
                
                # Replace the conditional in the Text with the variable
                modified_text = line.replace(f'\\({conditional_expr})', f'\\({var_name})')
                new_lines += modified_text
                
                return {
                    'file': file_path,
                    'line': line_num + 1,
                    'original': line.strip(),
                    'replacement': new_lines.strip(),
                    'message': f"Extract conditional expression to a variable before using in Text"
                }
        
        return {
            'file': file_path,
            'line': line_num + 1,
            'original': line.strip(),
            'message': "Manual fix required for this buildExpression issue"
        }
    
    def fix_deprecated_api(self, issue):
        """Generate a fix for deprecated API issues"""
        file_path = issue['file']
        with open(file_path, 'r') as f:
            content = f.read()
            lines = content.splitlines()
        
        line_num = issue['line'] - 1
        line = lines[line_num]
        
        # Map of patterns to their modern replacements
        api_replacements = {
            r'AVAsset\(url: (.+?)\)': r'AVURLAsset(url: \1)',
            r'(\w+)\.duration': r'try await \1.load(.duration)',
            r'(\w+)\.tracks\(withMediaType: (.+?)\)': r'try await \1.loadTracks(withMediaType: \2)',
            r'(\w+)\.nominalFrameRate': r'try await \1.load(.nominalFrameRate)',
            r'(\w+)\.naturalSize': r'try await \1.load(.naturalSize)',
            r'(\w+)\.copyCGImage\(at: (.+?), actualTime: (.+?)\)': r'\1.generateCGImageAsynchronously(for: \2) { cgImage, actualTime, error in',
        }
        
        for pattern, replacement in api_replacements.items():
            if re.search(pattern, line):
                new_line = re.sub(pattern, replacement, line)
                
                return {
                    'file': file_path,
                    'line': line_num + 1,
                    'original': line.strip(),
                    'replacement': new_line.strip(),
                    'message': f"Replace deprecated API with modern equivalent"
                }
        
        return {
            'file': file_path,
            'line': line_num + 1,
            'original': line.strip(),
            'message': "Manual fix required for this deprecated API"
        }
    
    def fix_sendable_conformance(self, issue):
        """Generate a fix for Sendable conformance issues"""
        file_path = issue['file']
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        line_num = issue['line'] - 1
        line = lines[line_num]
        
        class_match = re.search(r'class\s+(\w+)', line)
        if class_match:
            class_name = class_match.group(1)
            
            # Check if there's already a conformance list
            if ':' in line:
                new_line = line.replace(':', ': @unchecked Sendable,')
            else:
                new_line = line.replace(class_name, f"{class_name}: @unchecked Sendable")
            
            return {
                'file': file_path,
                'line': line_num + 1,
                'original': line.strip(),
                'replacement': new_line.strip(),
                'message': f"Add @unchecked Sendable conformance to {class_name}"
            }
        
        return {
            'file': file_path,
            'line': line_num + 1,
            'original': line.strip(),
            'message': "Manual fix required for Sendable conformance"
        }
    
    def apply_fix(self, fix):
        """Apply a suggested fix to the file"""
        file_path = fix['file']
        line_num = fix['line'] - 1
        
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        if 'replacement' in fix:
            lines[line_num] = fix['replacement'] + '\n'
            
            with open(file_path, 'w') as f:
                f.writelines(lines)
            
            return f"Applied fix to {file_path} line {fix['line']}"
        else:
            return f"No automatic fix available for {file_path} line {fix['line']}"

def main():
    parser = argparse.ArgumentParser(description='Xcode Assistant - Find and fix common Swift issues')
    parser.add_argument('project_path', help='Path to the Xcode project directory')
    parser.add_argument('--analyze', action='store_true', help='Analyze the project for issues')
    parser.add_argument('--fix', type=int, help='Fix a specific issue by index')
    parser.add_argument('--fix-all', action='store_true', help='Attempt to fix all issues')
    parser.add_argument('--report', action='store_true', help='Generate a JSON report of issues')
    
    args = parser.parse_args()
    
    assistant = XcodeAssistant(args.project_path)
    
    if args.analyze or args.report or args.fix is not None or args.fix_all:
        issues = assistant.analyze_project()
        print(f"Found {len(issues)} potential issues")
        
        if args.report:
            report = assistant.generate_report()
            print(report)
            
        if args.fix is not None:
            fix = assistant.suggest_fixes(args.fix)
            if isinstance(fix, dict):
                print(f"Suggested fix for issue {args.fix}:")
                print(json.dumps(fix, indent=2))
                
                confirm = input("Apply this fix? (y/n): ")
                if confirm.lower() == 'y':
                    result = assistant.apply_fix(fix)
                    print(result)
            else:
                print(fix)
                
        if args.fix_all:
            fixes = assistant.suggest_fixes()
            for i, fix in enumerate(fixes):
                print(f"\nIssue {i}:")
                print(json.dumps(fix, indent=2))
                
                confirm = input(f"Apply fix for issue {i}? (y/n/q to quit): ")
                if confirm.lower() == 'y':
                    result = assistant.apply_fix(fix)
                    print(result)
                elif confirm.lower() == 'q':
                    break
    else:
        # Default behavior: analyze and show issues
        issues = assistant.analyze_project()
        print(f"Found {len(issues)} potential issues:")
        
        for i, issue in enumerate(issues):
            print(f"\nIssue {i}: {issue['type']} in {issue['file']} line {issue['line']}")
            print(f"  {issue['message']}")
            print(f"  Suggestion: {issue['suggestion']}")

if __name__ == "__main__":
    main()
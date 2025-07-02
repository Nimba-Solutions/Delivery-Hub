#!/usr/bin/env python3
"""
Script to replace __PROJECT_NAME__ and __PROJECT_LABEL__ placeholders with values from cumulusci.yml
This script updates both filenames and file contents throughout the project.
"""

import os
import re
import yaml
import shutil
from pathlib import Path
from typing import Dict, List, Tuple


def load_cumulusci_config() -> Dict:
    """Load and parse the cumulusci.yml file."""
    try:
        with open('cumulusci.yml', 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
        return config
    except FileNotFoundError:
        raise FileNotFoundError("cumulusci.yml file not found in current directory")
    except yaml.YAMLError as e:
        raise ValueError(f"Error parsing cumulusci.yml: {e}")


def get_project_values(config: Dict) -> Tuple[str, str]:
    """Extract project name and label from cumulusci config."""
    try:
        project_name = config['project']['package']['name']  # Shulman_Intake (for filenames)
        project_label = config['project']['package']['name_managed']  # Shulman-Intake (for labels)
        return project_name, project_label
    except KeyError as e:
        raise ValueError(f"Missing required configuration in cumulusci.yml: {e}")


def find_files_with_placeholders(root_dir: str) -> List[Path]:
    """Find all files that contain __PROJECT_NAME__ or __PROJECT_LABEL__ placeholders."""
    files_to_update = []
    root_path = Path(root_dir)
    
    # Only search in force-app/ and unpackaged/ directories
    search_dirs = ['force-app', 'unpackaged']
    
    for search_dir in search_dirs:
        dir_path = root_path / search_dir
        if dir_path.exists():
            for file_path in dir_path.rglob('*'):
                if file_path.is_file():
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            if '__PROJECT_NAME__' in content or '__PROJECT_LABEL__' in content:
                                files_to_update.append(file_path)
                    except (UnicodeDecodeError, PermissionError):
                        # Skip binary files or files we can't read
                        continue
    
    return files_to_update


def find_files_with_placeholder_names(root_dir: str) -> List[Path]:
    """Find all files that have __PROJECT_NAME__ or __PROJECT_LABEL__ in their filename."""
    files_to_rename = []
    root_path = Path(root_dir)
    
    # Only search in force-app/ and unpackaged/ directories
    search_dirs = ['force-app', 'unpackaged']
    
    for search_dir in search_dirs:
        dir_path = root_path / search_dir
        if dir_path.exists():
            for file_path in dir_path.rglob('*'):
                if file_path.is_file():
                    if '__PROJECT_NAME__' in file_path.name or '__PROJECT_LABEL__' in file_path.name:
                        files_to_rename.append(file_path)
    
    return files_to_rename


def update_file_content(file_path: Path, project_name: str, project_label: str) -> bool:
    """Update file content by replacing placeholders."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Replace placeholders
        original_content = content
        content = content.replace('__PROJECT_NAME__', project_name)
        content = content.replace('__PROJECT_LABEL__', project_label)
        
        # Only write if content changed
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except (UnicodeDecodeError, PermissionError) as e:
        print(f"Warning: Could not update {file_path}: {e}")
        return False


def rename_file(file_path: Path, project_name: str, project_label: str) -> Path:
    """Rename file by replacing placeholders in filename."""
    new_name = file_path.name.replace('__PROJECT_NAME__', project_name)
    new_name = new_name.replace('__PROJECT_LABEL__', project_label)
    
    if new_name != file_path.name:
        new_path = file_path.parent / new_name
        try:
            file_path.rename(new_path)
            return new_path
        except OSError as e:
            print(f"Warning: Could not rename {file_path} to {new_path}: {e}")
            return file_path
    return file_path


def main():
    """Main function to execute the placeholder replacement."""
    print("Starting project placeholder replacement...")
    
    # Load configuration
    try:
        config = load_cumulusci_config()
        project_name, project_label = get_project_values(config)
        print(f"Project Name: {project_name}")
        print(f"Project Label: {project_label}")
    except Exception as e:
        print(f"Error loading configuration: {e}")
        return 1
    
    # Find files to update
    print("\nSearching for files with placeholders...")
    files_to_update = find_files_with_placeholders('.')
    files_to_rename = find_files_with_placeholder_names('.')
    
    print(f"Found {len(files_to_update)} files with placeholder content")
    print(f"Found {len(files_to_rename)} files with placeholder names")
    
    # Update file contents
    print("\nUpdating file contents...")
    content_updated = 0
    for file_path in files_to_update:
        if update_file_content(file_path, project_name, project_label):
            print(f"  Updated content: {file_path}")
            content_updated += 1
    
    # Rename files (do this after content updates to avoid path issues)
    print("\nRenaming files...")
    renamed = 0
    for file_path in files_to_rename:
        new_path = rename_file(file_path, project_name, project_label)
        if new_path != file_path:
            print(f"  Renamed: {file_path.name} -> {new_path.name}")
            renamed += 1
    
    print(f"\nSummary:")
    print(f"  Files with content updated: {content_updated}")
    print(f"  Files renamed: {renamed}")
    print("Placeholder replacement completed successfully!")


if __name__ == "__main__":
    exit(main()) 
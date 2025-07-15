# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

This is a Git offline bundle management system designed to create, restore, and import Git bundles for repositories with submodules. The system consists of three main bash scripts that work together:

### Core Components

1. **create-bundle.sh** - Creates Git bundles from source repositories
   - Handles branch switching and validation
   - Processes submodules recursively
   - Supports full code export or branch-specific export
   - Can compress bundles into ZIP files

2. **restore-bundle.sh** - Restores repositories from bundles
   - Extracts ZIP files containing bundles
   - Restores main repository and all submodules
   - Recreates proper Git repository structure

3. **import-bundle.sh** - Imports bundles into existing repositories
   - Merges bundle contents into existing repos
   - Handles submodule imports
   - Provides detailed import status reporting

4. **config.sh** - Configuration management
   - Centralizes all configuration variables
   - Provides validation functions
   - Supports environment variable overrides

### Key Functions

- `validate_config()` - Validates all configuration parameters (config.example.sh:45)
- `check_requirements()` - Verifies required commands are available
- `import_bundle()` - Core bundle import functionality (import-bundle.sh:197)
- `import_submodules()` - Handles submodule processing (import-bundle.sh:361)

## Common Commands

### Basic Operations
```bash
# Create bundles from source repository
./create-bundle.sh

# Restore repository from bundles
./restore-bundle.sh

# Import bundles into existing repository
./import-bundle.sh -s /path/to/repo -b /path/to/bundles
```

### Configuration
```bash
# Copy example configuration
cp config.example.sh config.sh

# Validate current configuration
./config.sh

# Check configuration with custom values
SOURCE_REPO=/path/to/repo ./config.sh
```

### Environment Variables
Key environment variables that can be set:
- `SOURCE_REPO` - Source repository path
- `BUNDLES_DIR` - Bundle output/input directory
- `RESTORE_DIR` - Restoration target directory
- `MAIN_REPO_NAME` - Main repository name
- `TARGET_BRANCH` - Branch to switch to before bundling
- `RENAME_BRANCH` - Branch name to use for bundling
- `FULL_CODE` - Whether to export full code history (true/false)
- `COMPRESS_BUNDLES` - Whether to compress bundles into ZIP (true/false)
- `LIMIT_COMMITS` - Limit number of commits to include

## Development Notes

### Script Structure
- All scripts use `set -e` for error handling
- Color-coded output functions (print_info, print_success, print_warning, print_error)
- Comprehensive parameter validation
- Temporary directory management with cleanup

### Configuration System
- Default values defined in config.example.sh
- Environment variable overrides supported
- Extensive validation for all parameters
- Branch name validation using regex patterns

### Error Handling
- Scripts exit on first error (set -e)
- Comprehensive requirement checking
- Directory and permission validation
- Git repository status verification

### Testing
The `test/` directory contains sample repositories and test data for development and validation.

## File Locations

- Main scripts: Root directory (*.sh)
- Configuration: config.sh (copy from config.example.sh)
- Test data: test/ directory
- Temporary files: .import_tmp/ (auto-created/cleaned)
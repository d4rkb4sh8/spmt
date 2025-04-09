⣾  Loading⣽  Loading⣻  Loading⢿  Loading⡿  Loading⣟  Loading⣯  Loading⣷  Loading⣾  Loading          
Here's a summary of the code in Markdown format:

```markdown
# System Package Manager Toolkit (spmt)

## Overview

This is a comprehensive system configuration management tool written in Bash. It provides functionality for backing up and restoring system configurations, including packages and desktop environments.

## Key Features

- Detects ytem distribution, package manager, and desktop environment
- Backs up packages and desktop configurations
- Restores backups
- Lists available backups
- Cleans up old backups

## Usage

The script supports various commands:

- `spmt -d`: Detect system information
- `spmt -b [PATH]`: Create system backup
- `spmt -r [PATH]`: Restore system from backup
- `spmt -l`: List available backups
- `spmt -c [DAYS]`: Clean up backups older than X days

## Configuration

- Uses color-coded output for better readability
- Defines variables for error handling and temporary file management
- Includes functions for showing help, version, and detecting system information

## Backup Process

1. Detects ytem details
2. Creates a backup directory with timestamp
3. Backs up packages based on the detected package manager
4. Backs up desktop-specific configurations
5. Saves metadata about the backup

## Restore Process

1. Loads metadata from the backup directory
2. Detects ytem details again
3. Restores packages based on the detected package manager
4. Restores desktop-specific configurations

## Additional Options

- Package-only backup/restore
- Desktop-only backup/restore
- Exclude third-party packages
- Skip font files, themes, and extensions during backup/restore

## Error Handling

Includes trap statements for SIGINT, SIGTERM, and ERR to ensure proper cleanup of temporary files in case of interruptions.
```


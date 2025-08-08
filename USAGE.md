# Hiera Log Function - Usage Examples

## Overview

The `hiera_log` function has been enhanced to support two logging modes:
- **File mode** (default): Logs to local file system using Ruby's Logger
- **Nexus mode**: Uploads log entries to a Nexus repository

## Configuration Options

### Common Options
- `mode`: Either 'file' or 'nexus' (default: 'file')
- `tag`: String to prepend to log messages (optional)

### File Mode Options
- `logdir`: Directory to store log files (default: '/var/log/puppetlabs')
- `filename`: Log file name (default: 'hiera.log')
- `size`: Maximum log file size in bytes (default: 1024000)
- `retention`: Number of log files to retain (default: 4)

### Nexus Mode Options
- `nexus_url`: **Required** - Base URL of the Nexus repository
- `nexus_directory`: **Required** - Directory path in Nexus to upload logs
- `nexus_username`: Username for authentication (optional)
- `nexus_password`: Password for authentication (optional)
- `nexus_password_file`: Path to file containing password (optional)

## Authentication Methods

### 1. Username and Password
```yaml
options:
  mode: nexus
  nexus_url: 'https://nexus.example.com/repository/raw-logs'
  nexus_directory: 'puppet/logs'
  nexus_username: 'puppet-user'
  nexus_password: 'secret-password'
```

### 2. Username and Password File
```yaml
options:
  mode: nexus
  nexus_url: 'https://nexus.example.com/repository/raw-logs'
  nexus_directory: 'puppet/logs'
  nexus_username: 'puppet-user'
  nexus_password_file: '/etc/puppetlabs/nexus_password'
```

### 3. No Authentication (if Nexus allows anonymous uploads)
```yaml
options:
  mode: nexus
  nexus_url: 'https://nexus.example.com/repository/raw-logs'
  nexus_directory: 'puppet/logs'
```


## Error Handling

The function will raise exceptions for:
- Invalid mode (not 'file' or 'nexus')
- Missing required Nexus options (`nexus_url`, `nexus_directory`)
- Failed password file reads
- Failed Nexus uploads (non-2xx HTTP response codes)

## Example Hiera Configuration

See `examples/hiera_config_examples.yaml` for complete configuration examples.

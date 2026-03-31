# Lidarr Artist Path Updater

This repository contains a shell script (`lidarr_update_artist_paths.sh`) designed to update artist paths in Lidarr based on your local directory structure.

## Overview

The script loops through a base music directory on your host system, which is organized by genre. For each artist found under a genre, it checks if the path in Lidarr matches the desired path (`/AudioMusic/<Genre>/<Artist>`). If it doesn't match, the script updates the artist's path directly in Lidarr.

## Features

- Updates only the top-level `path` property of each artist in Lidarr.
- Supports dry-run mode (default) to preview changes without applying them. Use `--apply` or `-a` to apply changes.
- Maintains detailed logs per genre, including:
  - Artists found
  - Artists not found
  - Current run log
- Configurable options for applying changes, parallel processing, and retry limits.

## Requirements

- [Lidarr](https://lidarr.audio/) with API access
- `jq` installed on the system for JSON processing
- Bash-compatible shell (tested on QNAP NAS)

## Usage

```sh
./lidarr_update_artist_paths.sh -g "Classical,Pop" [options]
```

### Options

- `-g, --genres` : Comma-separated list of genres to process (required)
- `-a, --apply`  : Actually apply path updates (default is dry-run)
- `-p, --parallel`   : Number of parallel updates (default: 5)
- `-r, --retries`    : Max retries for failed updates (default: 3)
- `-h, --help`   : Show help message

### Example

```sh
./lidarr_update_artist_paths.sh -g "Classical,Pop" --apply
```
This will scan the Classical and Pop directories and update any artist paths in Lidarr to match the host directory structure.

## Logging

All logs are stored under `./genres/<Genre>/`:

- `found_artists.log` - List of artists found and updated
- `notfound_artists.log` - Artists that could not be found in Lidarr
- Timestamped current run log for detailed actions

## License

MIT License


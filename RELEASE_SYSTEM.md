# Release System

This document describes the automated release system for Ratchet Chat.

## Overview

Releases are automated via GitHub Actions. When you publish a GitHub release, the system automatically:

1. Updates the version in `client/package.json`
2. Adds release notes to `client/public/CHANGELOG.md`
3. Commits changes back to `main`
4. Builds and pushes Docker images to GitHub Container Registry

## Creating a Release

### 1. Create a GitHub Release

Go to **Releases** → **Draft a new release** and:

- **Tag**: Use semantic versioning with `v` prefix (e.g., `v1.2.0`)
- **Target**: `main` branch
- **Title**: Version number or descriptive title

### 2. Write Release Notes

Use standard [Keep a Changelog](https://keepachangelog.com/) section headers:

```markdown
### Added
- New feature description
- Another new feature

### Changed
- Modified behavior description

### Fixed
- Bug fix description

### Removed
- Removed feature description

### Security
- Security fix description
```

The automation will:
- Extract these sections into the changelog
- Clean up PR references (e.g., "by @user in #123" is removed)
- Skip "What's Changed" headers and "Full Changelog" footers

### 3. Publish

Click **Publish release**. The GitHub Action will run automatically.

## What Gets Built

### Docker Images

Images are pushed to GitHub Container Registry:

```
ghcr.io/{owner}/{repo}/client:1.2.0
ghcr.io/{owner}/{repo}/client:1.2
ghcr.io/{owner}/{repo}/client:1
ghcr.io/{owner}/{repo}/client:latest
```

### Build Args

The Docker build includes version info that works without `.git`:

| Build Arg | Value |
|-----------|-------|
| `NEXT_PUBLIC_APP_VERSION` | Version from tag (e.g., `1.2.0`) |
| `NEXT_PUBLIC_CLIENT_COMMIT` | Git SHA of the release commit |

## File Structure

```
.github/
├── workflows/
│   └── release.yml          # Main release workflow
└── scripts/
    └── update-changelog.mjs # Changelog update script
```

## Manual Docker Build

To build locally with version info:

```bash
docker build \
  --build-arg NEXT_PUBLIC_APP_VERSION=1.2.0 \
  --build-arg NEXT_PUBLIC_CLIENT_COMMIT=$(git rev-parse HEAD) \
  -t ratchet-chat-client:1.2.0 \
  ./client
```

## Troubleshooting

### Version shows "unknown"

Ensure the Docker build includes the build args:
- `NEXT_PUBLIC_APP_VERSION`
- `NEXT_PUBLIC_CLIENT_COMMIT`

### Changelog not updated

Check that release notes use proper markdown headers (`### Added`, `### Fixed`, etc.). The script only recognizes standard Keep a Changelog sections.

### Workflow fails to push

Ensure the workflow has `contents: write` permission. This is configured in the workflow file but may need repository settings adjustment.

## Version Display

The version appears in:
- **Settings dialog** footer (click to see changelog)
- **App Info dialog** under Status tab
- A badge appears when users haven't seen the latest version's changelog

# rune-notes-bin AUR Package

Automated AUR packaging for rune on Arch Linux.

## Install

Use your AUR helper:

```bash
yay -S rune-notes-bin
```

## What This Repo Does

- Tracks published `eggfriedrice24/rune` GitHub releases.
- Packages the upstream x86_64 `.deb` as `rune-notes-bin`.
- Publishes `PKGBUILD` and `.SRCINFO` to the AUR package repo.

## Repo Layout

- `PKGBUILD`, `.SRCINFO`: AUR package metadata.
- `upstream.sha256`: last published upstream `.deb` checksum.
- `scripts/`: release check, metadata update, and AUR publish helpers.
- `.github/workflows/publish-aur.yml`: scheduled and manual AUR publishing workflow.

## Manual Update

```bash
scripts/check_upstream.sh
PKGBUILD_PATH=PKGBUILD STATE_FILE=upstream.sha256 scripts/update_pkgbuild.sh
makepkg --printsrcinfo > .SRCINFO
makepkg -f
git add PKGBUILD .SRCINFO upstream.sha256
git commit -m "chore(update): rune-notes-bin 0.1.4-1"
```

## Automation Setup

Required GitHub Actions secret:

- `AUR_SSH_PRIVATE_KEY`: private key allowed to push to `ssh://aur@aur.archlinux.org/rune-notes-bin.git`.

Optional variables:

- `UPSTREAM_REPO`: defaults to `eggfriedrice24/rune`.
- `AUR_COMMIT_NAME`: defaults to `rune-notes-ci`.
- `AUR_COMMIT_EMAIL`: defaults to `rune-notes-ci@users.noreply.github.com`.

The workflow can be run manually with `force_publish=true` to rebuild and push the current metadata even when the upstream checksum has not changed.

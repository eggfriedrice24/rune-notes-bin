#!/usr/bin/env bash
set -euo pipefail

PKGBUILD_PATH="${PKGBUILD_PATH:-PKGBUILD}"
STATE_FILE="${STATE_FILE:-upstream.sha256}"
PKGVER_CANDIDATE="${PKGVER_CANDIDATE:-}"
ASSET_SHA256="${ASSET_SHA256:-}"

if [[ -z "$PKGVER_CANDIDATE" ]]; then
  echo "PKGVER_CANDIDATE is required" >&2
  exit 1
fi

if [[ -z "$ASSET_SHA256" ]]; then
  echo "ASSET_SHA256 is required" >&2
  exit 1
fi

if [[ ! -f "$PKGBUILD_PATH" ]]; then
  echo "missing PKGBUILD at $PKGBUILD_PATH" >&2
  exit 1
fi

current_pkgver="$(awk -F= '/^pkgver=/{print $2; exit}' "$PKGBUILD_PATH")"
current_pkgrel="$(awk -F= '/^pkgrel=/{print $2; exit}' "$PKGBUILD_PATH")"

if [[ -z "$current_pkgver" || -z "$current_pkgrel" ]]; then
  echo "failed to read current pkgver/pkgrel from $PKGBUILD_PATH" >&2
  exit 1
fi

new_pkgver="$PKGVER_CANDIDATE"
if [[ "$new_pkgver" != "$current_pkgver" ]]; then
  new_pkgrel=1
else
  new_pkgrel=$((current_pkgrel + 1))
fi

sed -Ei "s/^pkgver=.*/pkgver=${new_pkgver}/" "$PKGBUILD_PATH"
sed -Ei "s/^pkgrel=.*/pkgrel=${new_pkgrel}/" "$PKGBUILD_PATH"
sed -Ei "s/^sha256sums_x86_64=\('.*'\)/sha256sums_x86_64=('${ASSET_SHA256}')/" "$PKGBUILD_PATH"

printf '%s\n' "$ASSET_SHA256" > "$STATE_FILE"

printf 'pkgver=%s\n' "$new_pkgver"
printf 'pkgrel=%s\n' "$new_pkgrel"
printf 'state_file=%s\n' "$STATE_FILE"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'pkgver=%s\n' "$new_pkgver"
    printf 'pkgrel=%s\n' "$new_pkgrel"
    printf 'state_file=%s\n' "$STATE_FILE"
  } >> "$GITHUB_OUTPUT"
fi

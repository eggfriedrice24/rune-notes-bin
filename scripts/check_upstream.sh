#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-eggfriedrice24/rune}"
UPSTREAM_TAG="${UPSTREAM_TAG:-}"
STATE_FILE="${STATE_FILE:-upstream.sha256}"
PKGBUILD_PATH="${PKGBUILD_PATH:-PKGBUILD}"
RELEASE_TAG_REGEX="${RELEASE_TAG_REGEX:-^v[0-9]+\.[0-9]+\.[0-9]+$}"
RELEASE_PRERELEASE="${RELEASE_PRERELEASE:-false}"
ASSET_REGEX="${ASSET_REGEX:-^rune_[0-9]+\.[0-9]+\.[0-9]+_amd64\.deb$}"
out_file="${GITHUB_OUTPUT:-}"

if [[ -n "$UPSTREAM_TAG" && ! "$UPSTREAM_TAG" =~ $RELEASE_TAG_REGEX ]]; then
  echo "upstream tag does not match release tag regex: $UPSTREAM_TAG" >&2
  exit 1
fi

if [[ -n "$UPSTREAM_TAG" ]]; then
  release_json="$(gh api "repos/$UPSTREAM_REPO/releases/tags/$UPSTREAM_TAG")"
else
  releases_json="$(gh api "repos/$UPSTREAM_REPO/releases?per_page=100")"
  release_json="$(jq -c \
    --arg regex "$RELEASE_TAG_REGEX" \
    --arg prerelease "$RELEASE_PRERELEASE" '
      map(
        select(
          (.draft | not)
          and (.prerelease == ($prerelease == "true"))
          and (.tag_name | test($regex))
        )
      )
      | first // empty
    ' <<<"$releases_json")"
fi

upstream_tag="$(jq -r '.tag_name // empty' <<<"$release_json")"
if [[ -z "$upstream_tag" ]]; then
  echo "failed to resolve matching upstream tag from $UPSTREAM_REPO" >&2
  exit 1
fi

if ! jq -e --arg prerelease "$RELEASE_PRERELEASE" '(.draft | not) and (.prerelease == ($prerelease == "true"))' <<<"$release_json" >/dev/null; then
  echo "upstream release is not publishable: $upstream_tag" >&2
  exit 1
fi

asset_json="$(jq -c --arg regex "$ASSET_REGEX" '
  .assets
  | map(select(.name | test($regex)))
  | first // empty
' <<<"$release_json")"

if [[ -z "$asset_json" || "$asset_json" == "null" ]]; then
  echo "failed to find amd64 deb asset in latest release for $UPSTREAM_REPO" >&2
  exit 1
fi

asset_name="$(jq -r '.name // empty' <<<"$asset_json")"
asset_url="$(jq -r '.browser_download_url // empty' <<<"$asset_json")"
asset_sha256="$(jq -r '.digest // empty' <<<"$asset_json")"
asset_sha256="${asset_sha256#sha256:}"

if [[ -z "$asset_name" || -z "$asset_url" ]]; then
  echo "incomplete deb asset metadata returned by GitHub" >&2
  exit 1
fi

if [[ -z "$asset_sha256" ]]; then
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT
  curl -fL --retry 3 --retry-delay 2 "$asset_url" -o "$tmp_dir/$asset_name"
  asset_sha256="$(sha256sum "$tmp_dir/$asset_name" | awk '{print $1}')"
fi

upstream_version="${upstream_tag#v}"
pkgver_candidate="$(printf '%s' "$upstream_version" | tr '-' '_' | tr -cd '[:alnum:]_.+')"

previous_sha256=""
if [[ -f "$STATE_FILE" ]]; then
  previous_sha256="$(tr -d '[:space:]' < "$STATE_FILE")"
fi

current_pkgver=""
if [[ -f "$PKGBUILD_PATH" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/{print $2; exit}' "$PKGBUILD_PATH")"
fi

changed="false"
if [[ "$asset_sha256" != "$previous_sha256" || "$pkgver_candidate" != "$current_pkgver" ]]; then
  changed="true"
fi

printf 'changed=%s\n' "$changed"
printf 'upstream_tag=%s\n' "$upstream_tag"
printf 'upstream_version=%s\n' "$upstream_version"
printf 'pkgver_candidate=%s\n' "$pkgver_candidate"
printf 'asset_name=%s\n' "$asset_name"
printf 'asset_url=%s\n' "$asset_url"
printf 'asset_sha256=%s\n' "$asset_sha256"
printf 'state_file=%s\n' "$STATE_FILE"
printf 'current_pkgver=%s\n' "$current_pkgver"

if [[ -n "$out_file" ]]; then
  {
    printf 'changed=%s\n' "$changed"
    printf 'upstream_tag=%s\n' "$upstream_tag"
    printf 'upstream_version=%s\n' "$upstream_version"
    printf 'pkgver_candidate=%s\n' "$pkgver_candidate"
    printf 'asset_name=%s\n' "$asset_name"
    printf 'asset_url=%s\n' "$asset_url"
    printf 'asset_sha256=%s\n' "$asset_sha256"
    printf 'state_file=%s\n' "$STATE_FILE"
    printf 'current_pkgver=%s\n' "$current_pkgver"
  } >> "$out_file"
fi

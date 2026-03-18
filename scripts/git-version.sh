#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if version="$(git -C "$repo_root" describe --tags --always --dirty 2>/dev/null)"; then
  printf '%s\n' "$version"
  exit 0
fi

fallback_version="$(sed -nE "s/^version:[[:space:]]*([^+[:space:]]+).*/\1/p" "$repo_root/pubspec.yaml" | head -n 1)"
printf '%s\n' "${fallback_version:-0.1.0-dev}"

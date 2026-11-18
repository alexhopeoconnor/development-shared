#!/usr/bin/env bash

# Source-only Git checks for callers that choose to enforce release-source
# integrity. They do not infer a version, tag, remote, registry, or policy.

require_clean_release_source() {
  local source_path="${1-}"
  local repository status submodules

  repository="$(git -C "$source_path" rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'Release source must belong to a Git checkout: %s\n' "$source_path" >&2
    return 1
  }
  status="$(git -C "$repository" status --porcelain --untracked-files=normal --ignore-submodules=none)" || return 1
  submodules="$(git -C "$repository" submodule status --recursive)" || return 1
  if [[ -n "$status" || "$submodules" =~ (^|$'\n')[-+U] ]]; then
    printf 'Release source is dirty or has incomplete submodules: %s\n' "$repository" >&2
    return 1
  fi
}

require_same_release_repository() {
  local repository="${1-}"
  local path="${2-}"
  local actual

  [[ -d "$path" ]] || path="$(dirname "$path")"
  actual="$(git -C "$path" rev-parse --show-toplevel 2>/dev/null)" || return 1
  if [[ "$actual" != "$repository" ]]; then
    printf 'Release build inputs must belong to the project repository: %s\n' "$path" >&2
    return 1
  fi
}

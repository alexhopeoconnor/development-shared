#!/usr/bin/env bash

# Source-only helpers for SemVer validation and narrow .csproj metadata reads.
# They deliberately do not select a project, derive a release version, or edit
# source files; those decisions belong to the consuming application.

if [[ "${DEVELOPMENT_SHARED_VERSIONING_LOADED:-}" != "1" ]]; then
  readonly DEVELOPMENT_SHARED_VERSIONING_LOADED=1
  readonly DEVELOPMENT_SHARED_SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
  readonly DEVELOPMENT_SHARED_IMAGE_VERSION_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
  readonly DEVELOPMENT_SHARED_STABLE_VERSION_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
fi

require_option_value() {
  local option="${1-}"
  local value="${2-}"

  if [[ -z "$value" || "$value" == -* ]]; then
    printf '%s requires a value.\n' "$option" >&2
    return 1
  fi
}

validate_package_version() {
  local version="${1-}"

  if [[ ! "$version" =~ $DEVELOPMENT_SHARED_SEMVER_RE ]]; then
    printf 'Package version must be SemVer; received %q.\n' "$version" >&2
    return 1
  fi
}

validate_image_version() {
  local version="${1-}"

  if [[ ! "$version" =~ $DEVELOPMENT_SHARED_IMAGE_VERSION_RE ]]; then
    printf 'Image version must be Docker-tag-compatible SemVer; received %q.\n' "$version" >&2
    return 1
  fi
}

# Print the first simple value for an explicitly selected project element.
# This is intentionally a narrow metadata reader, not a general XML parser.
read_csproj_value() {
  local csproj_path="${1-}"
  local element="${2-}"

  if [[ ! -f "$csproj_path" || ! -r "$csproj_path" ]]; then
    printf 'Project file must be a readable regular file: %s\n' "$csproj_path" >&2
    return 1
  fi
  if [[ ! "$element" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]; then
    printf 'Project metadata element is invalid: %s\n' "$element" >&2
    return 1
  fi

  sed -n "s|.*<$element>\\([^<]*\\)</$element>.*|\\1|p" "$csproj_path" | head -n 1 | tr -d ' \t'
}

read_csproj_version() {
  read_csproj_value "${1-}" Version
}

read_csproj_package_id() {
  local csproj_path="${1-}"
  local package_id

  package_id="$(read_csproj_value "$csproj_path" PackageId)" || return 1
  if [[ -z "$package_id" ]]; then
    package_id="$(basename "$csproj_path" .csproj)"
  fi
  printf '%s\n' "$package_id"
}

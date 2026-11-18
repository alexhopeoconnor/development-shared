#!/usr/bin/env bash

# Pack one explicitly selected .NET project. This command never resolves or
# writes a package version, reads Git state, selects a registry, or publishes.

DEVELOPMENT_SHARED_PACKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/versioning.sh
source "$DEVELOPMENT_SHARED_PACKER_DIR/lib/versioning.sh"

pack_nuget_project() {
  local project_path="${1-}"
  local output_dir="${2-}"
  local configuration="${3-}"
  local build_mode="${4-}"
  local restore_mode="${5-}"
  local source_revision="${6-}"
  local -a command

  [[ -f "$project_path" ]] || {
    printf 'Project file does not exist: %s\n' "$project_path" >&2
    return 1
  }
  case "$build_mode" in
    build|no-build) ;;
    *)
      printf 'Build mode must be build or no-build; received %s.\n' "$build_mode" >&2
      return 1
      ;;
  esac
  case "$restore_mode" in
    restore|no-restore) ;;
    *)
      printf 'Restore mode must be restore or no-restore; received %s.\n' "$restore_mode" >&2
      return 1
      ;;
  esac

  mkdir -p "$output_dir" || return 1
  command=(dotnet pack "$project_path" --configuration "$configuration" --output "$output_dir")
  [[ "$build_mode" != no-build ]] || command+=(--no-build)
  [[ "$restore_mode" != no-restore ]] || command+=(--no-restore)
  if [[ -n "$source_revision" ]]; then
    command+=("-p:RepositoryCommit=$source_revision" "-p:SourceRevisionId=$source_revision")
  fi
  "${command[@]}"
}

pack_nuget_package_usage() {
  cat <<'EOF'
Usage: pack-nuget-package.sh --project <path> --output-dir <path> [OPTIONS]

Pack an explicitly selected project without changing its version or publishing
an artifact.

Options:
  --configuration <name>        Build configuration (default: Release)
  --build-mode build|no-build   Whether dotnet may build (default: build)
  --no-build                    Alias for --build-mode no-build
  --no-restore                  Pass --no-restore to dotnet pack
  --source-revision <value>     Explicit source revision metadata for the package
  -h, --help                    Show this help
EOF
}

pack_nuget_package_main() {
  local project_path=""
  local output_dir=""
  local configuration="Release"
  local build_mode="build"
  local restore_mode="restore"
  local source_revision=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        require_option_value "$1" "${2-}" || return 2
        project_path="$2"
        shift 2
        ;;
      --output-dir)
        require_option_value "$1" "${2-}" || return 2
        output_dir="$2"
        shift 2
        ;;
      --configuration)
        require_option_value "$1" "${2-}" || return 2
        configuration="$2"
        shift 2
        ;;
      --build-mode)
        require_option_value "$1" "${2-}" || return 2
        build_mode="$2"
        shift 2
        ;;
      --no-build)
        build_mode="no-build"
        shift
        ;;
      --no-restore)
        restore_mode="no-restore"
        shift
        ;;
      --source-revision)
        require_option_value "$1" "${2-}" || return 2
        source_revision="$2"
        shift 2
        ;;
      -h|--help)
        pack_nuget_package_usage
        return 0
        ;;
      *)
        printf 'Unknown option: %s\n' "$1" >&2
        pack_nuget_package_usage >&2
        return 2
        ;;
    esac
  done

  [[ -n "$project_path" ]] || {
    printf 'Error: --project is required.\n' >&2
    return 2
  }
  [[ -n "$output_dir" ]] || {
    printf 'Error: --output-dir is required.\n' >&2
    return 2
  }
  pack_nuget_project "$project_path" "$output_dir" "$configuration" "$build_mode" "$restore_mode" "$source_revision"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  pack_nuget_package_main "$@"
fi

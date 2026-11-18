#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PACKER="$REPO_ROOT/tooling/bash/pack-nuget-package.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local value="$1"
  local expected="$2"
  [[ "$value" == *"$expected"* ]] || fail "expected [$expected] in [$value]"
}

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/out"
cat > "$TEST_ROOT/Example.csproj" <<'EOF'
<Project>
  <PropertyGroup>
    <PackageId>Example.Package</PackageId>
    <Version>1.2.3</Version>
  </PropertyGroup>
</Project>
EOF
cat > "$TEST_ROOT/bin/dotnet" <<'EOF'
#!/usr/bin/env bash
if [[ "${SOURCE_ONLY_PHASE:-false}" == true ]]; then
  printf 'dotnet %s\n' "$*" >> "$SOURCE_TOOL_LOG"
  exit 97
fi
printf '%s\n' "$*" >> "$DOTNET_LOG"
EOF
chmod +x "$TEST_ROOT/bin/dotnet"
for tool in git docker; do
  cat > "$TEST_ROOT/bin/$tool" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$SOURCE_TOOL_LOG"
exit 97
EOF
  chmod +x "$TEST_ROOT/bin/$tool"
done

# Loading each public entrypoint must not execute a tool or overwrite a
# consumer's unscoped SCRIPT_DIR variable.
SOURCE_TOOL_LOG="$TEST_ROOT/source-tools.log"
export SOURCE_TOOL_LOG
export SOURCE_ONLY_PHASE=true
export PATH="$TEST_ROOT/bin:$PATH"
SCRIPT_DIR='consumer-owned-script-dir'
source "$REPO_ROOT/tooling/bash/lib/versioning.sh"
source "$REPO_ROOT/tooling/bash/lib/release-source.sh"
source "$REPO_ROOT/tooling/bash/lib/docker-image.sh"
source "$PACKER"
unset SOURCE_ONLY_PHASE
[[ "$SCRIPT_DIR" == consumer-owned-script-dir ]] || fail 'sourcing packer overwrote caller SCRIPT_DIR'
[[ -z "${DEVELOPMENT_SHARED_BUILT_DOCKER_IMAGE_ID:-}" ]] || fail 'sourcing image library set a build identity'
[[ ! -s "$SOURCE_TOOL_LOG" ]] || fail 'sourcing public entrypoints invoked a tool'

validate_package_version 1.2.3
validate_image_version 1.2.3-rc.1
[[ "$(read_csproj_version "$TEST_ROOT/Example.csproj")" == 1.2.3 ]] || fail 'project version reader failed'
[[ "$(read_csproj_package_id "$TEST_ROOT/Example.csproj")" == Example.Package ]] || fail 'project package-id reader failed'

# Source checks use the explicit caller path, rather than the location of the
# sourced library or pack command.
TRACKED_SOURCE="$TEST_ROOT/tracked-source"
mkdir -p "$TRACKED_SOURCE"
touch "$TRACKED_SOURCE/Input.csproj"
GIT_LOG="$TEST_ROOT/git.log"
git() {
  printf '%s\n' "$*" >> "$GIT_LOG"
  case "$*" in
    "-C $TRACKED_SOURCE rev-parse --show-toplevel") printf '%s\n' "$TRACKED_SOURCE" ;;
    "-C $TRACKED_SOURCE status --porcelain --untracked-files=normal --ignore-submodules=none") ;;
    "-C $TRACKED_SOURCE submodule status --recursive") ;;
    *) printf 'unexpected git call: %s\n' "$*" >&2; return 8 ;;
  esac
}
require_clean_release_source "$TRACKED_SOURCE"
require_same_release_repository "$TRACKED_SOURCE" "$TRACKED_SOURCE/Input.csproj"
assert_contains "$(<"$GIT_LOG")" "-C $TRACKED_SOURCE rev-parse --show-toplevel"
[[ "$(<"$GIT_LOG")" != *"$REPO_ROOT rev-parse"* ]] || fail 'source check used its own script directory'

DOTNET_LOG="$TEST_ROOT/dotnet.log" PATH="$TEST_ROOT/bin:$PATH" \
  "$PACKER" --project "$TEST_ROOT/Example.csproj" --output-dir "$TEST_ROOT/out" \
  --configuration Debug --no-build --no-restore --source-revision abc123

invocation="$(<"$TEST_ROOT/dotnet.log")"
assert_contains "$invocation" "pack $TEST_ROOT/Example.csproj --configuration Debug --output $TEST_ROOT/out"
assert_contains "$invocation" "--no-build"
assert_contains "$invocation" "--no-restore"
assert_contains "$invocation" "-p:RepositoryCommit=abc123"
assert_contains "$invocation" "-p:SourceRevisionId=abc123"
[[ "$invocation" != *"PackageVersion"* ]] || fail 'packer must not override the package version'

printf 'pack-nuget-package tests passed.\n'

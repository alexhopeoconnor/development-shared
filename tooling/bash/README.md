# Bash tooling

The libraries take explicit inputs and leave release policy to the application
wrapper. Source exactly the library needed by a script:

```bash
source "$COMMON_ROOT/tooling/bash/lib/versioning.sh"
source "$COMMON_ROOT/tooling/bash/lib/release-source.sh"
source "$COMMON_ROOT/tooling/bash/lib/docker-image.sh"
```

`versioning.sh` provides `require_option_value`, SemVer validation, and narrow
project metadata readers:

```bash
validate_package_version "$VERSION"
package_id="$(read_csproj_package_id "$PROJECT_FILE")"
```

`release-source.sh` provides optional clean-source and same-repository checks:

```bash
require_clean_release_source "$PROJECT_ROOT"
require_same_release_repository "$PROJECT_ROOT" "$PROJECT_FILE"
```

`docker-image.sh` only performs explicit operations. Callers supply the build
context, Dockerfile, tags, labels, optional configuration file, and all source
metadata. `build_docker_image` stores the verified immutable result in
`DEVELOPMENT_SHARED_BUILT_DOCKER_IMAGE_ID`; pass that value to
`push_existing_docker_image` if the caller's own policy permits publication.

`pack-nuget-package.sh` packs one selected project without computing or
changing its version and never publishes. It requires `--project` and
`--output-dir`; configuration and build/restore choices are explicit:

```bash
tooling/bash/pack-nuget-package.sh \
  --project "$PROJECT_FILE" \
  --output-dir "$PACKAGE_OUTPUT" \
  --configuration Release \
  --no-build \
  --no-restore \
  --source-revision "$SOURCE_REVISION"
```

The optional source revision is passed to the package as source metadata. The
command does not inspect Git or derive it.

## Tests

Run the focused shell checks from the repository root:

```bash
bash tooling/bash/tests/pack-nuget-package-tests.sh
```

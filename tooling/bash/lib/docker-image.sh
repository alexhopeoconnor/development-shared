#!/usr/bin/env bash

# Explicit image build and publication primitives. A caller supplies all
# identity metadata and decides whether and where publication is permitted.

if [[ "${DEVELOPMENT_SHARED_DOCKER_IMAGE_LOADED:-}" != "1" ]]; then
  readonly DEVELOPMENT_SHARED_DOCKER_IMAGE_LOADED=1
  DEVELOPMENT_SHARED_BUILT_DOCKER_IMAGE_ID=""
fi

verify_docker_image_labels() {
  local image="${1-}"
  local name expected actual
  shift || return 1

  for name in version revision created source; do
    expected="${1-}"
    shift || return 1
    actual="$(docker image inspect --format "{{ index .Config.Labels \"org.opencontainers.image.$name\" }}" "$image")" || return 1
    if [[ "$actual" != "$expected" ]]; then
      printf 'Built image label is missing or incorrect: org.opencontainers.image.%s. Nothing was pushed.\n' "$name" >&2
      return 1
    fi
  done
}

# Implements the explicit build operation used by build_docker_image. The
# namespaced form lets compatibility layers preserve legacy result variables
# without redefining the public function recursively.
development_shared_build_docker_image() {
  local context="${1-}" dockerfile="${2-}" image="${3-}" version="${4-}" revision="${5-}"
  local created="${6-}" source="${7-}" package_config="${8-}" identity_file identity
  shift 8 || return 1

  DEVELOPMENT_SHARED_BUILT_DOCKER_IMAGE_ID=""
  identity_file="$(mktemp)" || return 1
  local -a command=(docker build -f "$dockerfile" --iidfile "$identity_file")
  [[ -z "$package_config" ]] || command+=(--secret "id=nugetconfig,src=$package_config")
  command+=("$@"
    --build-arg "APP_VERSION=$version" --build-arg "VCS_REF=$revision"
    --build-arg "BUILD_DATE=$created" --build-arg "REPOSITORY_URL=$source"
    --label "org.opencontainers.image.version=$version"
    --label "org.opencontainers.image.revision=$revision"
    --label "org.opencontainers.image.created=$created"
    --label "org.opencontainers.image.source=$source" -t "$image" "$context")
  if ! "${command[@]}"; then
    rm -f "$identity_file"
    return 1
  fi
  identity="$(<"$identity_file")"
  rm -f "$identity_file"
  if [[ ! "$identity" =~ ^sha256:[[:xdigit:]]{64}$ ]]; then
    printf 'Docker did not report a valid immutable build identity. Nothing was pushed.\n' >&2
    return 1
  fi
  verify_docker_image_labels "$identity" "$version" "$revision" "$created" "$source" || return 1
  DEVELOPMENT_SHARED_BUILT_DOCKER_IMAGE_ID="$identity"
}

# Sets DEVELOPMENT_SHARED_BUILT_DOCKER_IMAGE_ID to Docker's immutable build
# identity. The optional configuration path is supplied to BuildKit as the
# conventional `nugetconfig` secret; it is never copied into the context.
build_docker_image() {
  development_shared_build_docker_image "$@"
}

# Publish an already inspected immutable object. It never rebuilds an image.
push_existing_docker_image() {
  local identity="${1-}" destination="${2-}" current

  [[ "$identity" =~ ^sha256:[[:xdigit:]]{64}$ ]] || {
    printf 'Publication requires an immutable Docker image identity.\n' >&2
    return 1
  }
  docker tag "$identity" "$destination" || return 1
  current="$(docker image inspect --format '{{.Id}}' "$destination")" || return 1
  if [[ "$current" != "$identity" ]]; then
    printf 'Image identity changed before publication: %s\n' "$destination" >&2
    return 1
  fi
  docker push "$destination" || {
    printf 'Push failed for %s; inspect the destination before retrying because remote completion is uncertain.\n' "$destination" >&2
    return 1
  }
}

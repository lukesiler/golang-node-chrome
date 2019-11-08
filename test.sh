#!/bin/bash

IMAGE_NAME=$(yq r data.yaml data.image-name)
SEMVER=$(yq r data.yaml data.semver)

docker run --rm ${IMAGE_NAME}:v${SEMVER} yq --version
docker run --rm ${IMAGE_NAME}:v${SEMVER} jq --help
docker run --rm ${IMAGE_NAME}:v${SEMVER} go version
docker run --rm ${IMAGE_NAME}:v${SEMVER} ginkgo version
docker run --rm ${IMAGE_NAME}:v${SEMVER} node -v
docker run --rm ${IMAGE_NAME}:v${SEMVER} git version
docker run --rm ${IMAGE_NAME}:v${SEMVER} google-chrome-stable --version

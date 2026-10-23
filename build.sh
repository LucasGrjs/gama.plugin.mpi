#!/bin/bash
set -e

ROOT=$(dirname "${BASH_SOURCE[0]}")

if [ "$IS_DEPLOY" == "true" ]; then
    # Derive GAMA p2 version from branch name: GAMA_YYYY-MM → YYYY.MM
    BRANCH="${REF_NAME:-$(git rev-parse --abbrev-ref HEAD)}"
else
    # Get the name of the default branch
    BRANCH="${REF_NAME:-$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's/origin\///')}"
    SKIP_PLUGINS="-Djarsigner.skip=true -Dwagon.skip=true"
fi

if [[ "$BRANCH" =~ GAMA_([0-9]{4}-[0-9]{2}) ]]; then
    GAMA_P2_VERSION="${BASH_REMATCH[1]}"
    echo "Branch ${BRANCH} → gama.p2.version=${GAMA_P2_VERSION}"
else
    echo "ERROR: branch '${BRANCH}' does not match GAMA_YYYY-MM"
    exit 1
fi

# The signing keystore and SCP credentials are only set up for deploy runs (see
# build.yml). On compile-only runs, skip jarsigner and don't activate the p2Repo
# profile (which is what triggers the SCP upload of gama.plugin.p2updatesite) so
# CI doesn't fail trying to sign/upload with credentials that were never imported.
JARSIGNER_SKIP="true"
DEPLOY_PROFILE=()
if [[ "${IS_DEPLOY:-false}" == "true" ]]; then
    JARSIGNER_SKIP="false"
    DEPLOY_PROFILE=(-P p2Repo)
fi

cd "${ROOT}/gama.plugin.parent"
mvn clean install -B -e \
    -Dgama.p2.version="${GAMA_P2_VERSION}" \
    -Ddeploy.subdir="${PLUGIN_REPO_NAME}" \
    -Dtycho.p2.transport.min-cache-minutes=0 \
    -Dtycho.equinox.resolver.uses=true \
    -P p2Repo \
    -Djarsigner.skip="${JARSIGNER_SKIP}" \
    "${DEPLOY_PROFILE[@]}" \
    --settings ../settings.xml \
    $SKIP_PLUGINS

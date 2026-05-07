#!/usr/bin/env bash

set -euo pipefail

# Default values (can be overridden with flags).
CORE_PACKAGE_VERSION_ID="${CORE_PACKAGE_VERSION_ID:-04tKB000000xZJ5YAM}"
TARGET_ORG_ALIAS="${TARGET_ORG_ALIAS:-}"
INSTALLATION_SCOPE="${INSTALLATION_SCOPE:-AllUsers}"
LOGIN_HOST="${LOGIN_HOST:-login.salesforce.com}"

usage() {
  echo "Install Case Intelligence Core package and AI source metadata."
  echo
  echo "Usage:"
  echo "  ./scripts/install-core-and-ai.sh --target-org <alias-or-username> [options]"
  echo
  echo "Options:"
  echo "  --target-org <value>           Required. Org alias or username."
  echo "  --core-package-version-id <id> Optional. Defaults to ${CORE_PACKAGE_VERSION_ID}"
  echo "  --scope <AllUsers|AdminsOnly>  Optional. Defaults to ${INSTALLATION_SCOPE}"
  echo "  --login-host <host>            Optional. login.salesforce.com or test.salesforce.com"
  echo "  --help                          Show help."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org)
      TARGET_ORG_ALIAS="$2"
      shift 2
      ;;
    --core-package-version-id)
      CORE_PACKAGE_VERSION_ID="$2"
      shift 2
      ;;
    --scope)
      INSTALLATION_SCOPE="$2"
      shift 2
      ;;
    --login-host)
      LOGIN_HOST="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${TARGET_ORG_ALIAS}" ]]; then
  echo "Error: --target-org is required."
  usage
  exit 1
fi

if ! command -v sf >/dev/null 2>&1; then
  echo "Error: Salesforce CLI (sf) not found in PATH."
  exit 1
fi

echo "Step 1/5: Validating target org auth..."
sf org display --target-org "${TARGET_ORG_ALIAS}" >/dev/null

echo "Step 2/5: Installing core package ${CORE_PACKAGE_VERSION_ID}..."
sf package install \
  --package "${CORE_PACKAGE_VERSION_ID}" \
  --target-org "${TARGET_ORG_ALIAS}" \
  --security-type "${INSTALLATION_SCOPE}" \
  --publish-wait 10 \
  --wait 30 \
  --no-prompt

echo "Step 3/5: Deploying AI metadata from source (force-app-ai)..."
sf project deploy start \
  --source-dir "force-app-ai" \
  --target-org "${TARGET_ORG_ALIAS}" \
  --wait 30

echo "Step 4/5: Assigning permission set..."
sf org assign permset \
  --name "Case_Intelligence_User" \
  --target-org "${TARGET_ORG_ALIAS}"

echo "Step 5/5: Completed."
echo
echo "Next manual step:"
echo "- Verify flow 'Agentforce_Case_Classifier' is active in the target org."
echo "- Add LWC components to the Case record page."
echo
echo "Open org:"
echo "sf org open --target-org \"${TARGET_ORG_ALIAS}\""

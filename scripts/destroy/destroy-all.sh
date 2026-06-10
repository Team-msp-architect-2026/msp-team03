#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OTP="${1:-}"

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/config.sh"
aegis_load_config "${REPO_ROOT}"
# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/terraform.sh"

DESTROY_IOT="${DESTROY_IOT:-false}"
DESTROY_DATA_DASHBOARD="${DESTROY_DATA_DASHBOARD:-true}"
DESTROY_REPORTING="${DESTROY_REPORTING:-true}"
DESTROY_DATA_PIPE="${DESTROY_DATA_PIPE:-true}"
DESTROY_HUB="${DESTROY_HUB:-true}"
DESTROY_FOUNDATION="${DESTROY_FOUNDATION:-false}"
DATA_DASHBOARD_ROOT="${REPO_ROOT}/infra/data-dashboard"
REPORTING_ROOT="${REPO_ROOT}/infra/reporting"
DATA_PIPE_ROOT="${REPO_ROOT}/infra/data-pipeline"
FOUNDATION_ROOT="${REPO_ROOT}/infra/foundation"
export DESTROY_FOUNDATION DESTROY_DATA_DASHBOARD

cd "${REPO_ROOT}"

if [[ "${DESTROY_IOT}" == "true" ]]; then
  echo "Deleting K3s IoT Secret before AWS cleanup. Enter the SSH password if prompted."
  scripts/destroy/destroy-k3s-iot-secret.sh
  export SKIP_K3S_IOT_SECRET_DESTROY=true
fi

if [[ "${DESTROY_IOT}" == "true" || "${DESTROY_DATA_DASHBOARD}" == "true" || \
  "${DESTROY_REPORTING}" == "true" || \
  "${DESTROY_DATA_PIPE}" == "true" || \
  "${DESTROY_HUB}" == "true" || "${DESTROY_FOUNDATION}" == "true" ]]; then
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/scripts/lib/aws-mfa.sh"
  aegis_ensure_aws_mfa "${OTP}"
fi

echo "Destroy scope: iot=${DESTROY_IOT}, data-dashboard-runtime=${DESTROY_DATA_DASHBOARD}, reporting=${DESTROY_REPORTING}, data-pipe=${DESTROY_DATA_PIPE}, hub=${DESTROY_HUB}, foundation=${DESTROY_FOUNDATION}"
echo "Preserved by default: Foundation, IoT certificate/K3s Secret, Dashboard permanent, Dashboard DNS."

if [[ "${DESTROY_IOT}" == "true" ]]; then
  scripts/destroy/destroy-iot-factory-a.sh "${OTP}"
fi

if [[ "${DESTROY_DATA_DASHBOARD}" == "true" ]]; then
  state_status=0
  aegis_terraform_state_has_resources "${DATA_DASHBOARD_ROOT}" || state_status=$?
  if [[ "${state_status}" -eq 0 ]]; then
    scripts/destroy/destroy-data-dashboard.sh --yes --otp "${OTP}"
  elif [[ "${state_status}" -eq 1 ]]; then
    echo "Skipped data-dashboard runtime destroy: Terraform state is accessible but empty."
  else
    echo "Data-dashboard runtime Terraform state is not accessible. Refusing to assume it is safe to destroy." >&2
    exit 1
  fi
fi

if [[ "${DESTROY_REPORTING}" == "true" ]]; then
  state_status=0
  aegis_terraform_state_has_resources "${REPORTING_ROOT}" || state_status=$?
  if [[ "${state_status}" -eq 0 ]]; then
    scripts/destroy/destroy-reporting.sh "${OTP}"
  elif [[ "${state_status}" -eq 1 ]]; then
    echo "Skipped reporting destroy: Terraform state is accessible but empty."
  else
    echo "Reporting Terraform state is not accessible. Refusing to assume it is safe to destroy." >&2
    exit 1
  fi
fi

if [[ "${DESTROY_DATA_PIPE}" == "true" ]]; then
  state_status=0
  aegis_terraform_state_has_resources "${DATA_PIPE_ROOT}" || state_status=$?
  if [[ "${state_status}" -eq 0 ]]; then
    scripts/destroy/destroy-data-pipe.sh "${OTP}"
  elif [[ "${state_status}" -eq 1 ]]; then
    echo "Skipped data-pipeline destroy: Terraform state is accessible but empty."
  else
    echo "Data-pipeline Terraform state is not accessible. Refusing to assume it is safe to destroy." >&2
    exit 1
  fi
fi

if [[ "${DESTROY_HUB}" == "true" ]]; then
  aegis_terraform_require_state_resources "${FOUNDATION_ROOT}" "foundation"

  scripts/destroy/destroy-hub.sh --yes "${OTP}"
fi

if [[ "${DESTROY_FOUNDATION}" == "true" ]]; then
  scripts/destroy/destroy-foundation.sh "${OTP}"
else
  echo "Skipped foundation destroy. Set DESTROY_FOUNDATION=true to include it."
fi

echo "Destroy flow completed."

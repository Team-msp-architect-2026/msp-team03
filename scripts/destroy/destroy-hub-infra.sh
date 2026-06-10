#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OTP=""
FOUNDATION_ROOT="${REPO_ROOT}/infra/foundation"
PLAN_ONLY=false
CONFIRM_DESTROY=false
PLAN_FILE="tfplan.destroy-hub"

usage() {
  cat <<'USAGE'
Usage: scripts/destroy/destroy-hub-infra.sh [--plan-only] --yes [MFA_OTP]

Destroys the Hub Terraform root only. Foundation state must be readable because
Hub reads Foundation outputs. Use --plan-only to create and inspect the destroy
plan without applying it.

Options:
  --plan-only  Create a destroy plan and exit without applying it.
  --yes        Required to apply the destroy plan.
  -h, --help   Show this help.
USAGE
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --plan-only)
      PLAN_ONLY=true
      ;;
    --yes)
      CONFIRM_DESTROY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      if [[ "$#" -gt 0 ]]; then
        OTP="$1"
        shift
      fi
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "${OTP}" ]]; then
        echo "Unexpected extra argument: $1" >&2
        usage >&2
        exit 1
      fi
      OTP="$1"
      ;;
  esac
  shift
done

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/config.sh"
aegis_load_config "${REPO_ROOT}"
# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/aws-mfa.sh"
# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/terraform.sh"

aegis_ensure_aws_mfa "${OTP}"
aegis_terraform_require_state_resources "${FOUNDATION_ROOT}" "foundation"

cd "${REPO_ROOT}/infra/hub"

export AWS_RETRY_MODE="${AWS_RETRY_MODE:-adaptive}"
export AWS_MAX_ATTEMPTS="${AWS_MAX_ATTEMPTS:-10}"

terraform init
terraform validate
terraform plan -destroy -out="${PLAN_FILE}"

if [[ "${PLAN_ONLY}" == "true" ]]; then
  echo "Plan only mode enabled. Review infra/hub/${PLAN_FILE}, then rerun with --yes to apply."
  exit 0
fi

if [[ "${CONFIRM_DESTROY}" != "true" ]]; then
  echo "Refusing to destroy Hub infra without --yes. Review infra/hub/${PLAN_FILE} first." >&2
  exit 1
fi

terraform apply "${PLAN_FILE}"
rm -f "${PLAN_FILE}"

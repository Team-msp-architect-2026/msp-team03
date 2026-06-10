#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OTP=""
PLAN_ONLY=false
CONFIRM_DESTROY=false

usage() {
  cat <<'USAGE'
Usage: scripts/destroy/destroy-hub.sh [--plan-only] --yes [MFA_OTP]

Destroys Hub platform resources, then Hub Terraform infrastructure.
Use --plan-only to create only the Hub Terraform destroy plan. Platform cleanup
is skipped in plan-only mode.

Options:
  --plan-only  Create infra/hub destroy plan and exit without applying it.
  --yes        Required to run platform cleanup and apply Hub infra destroy.
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
aegis_ensure_aws_mfa "${OTP}"

if [[ "${PLAN_ONLY}" == "true" ]]; then
  "${SCRIPT_DIR}/destroy-hub-infra.sh" --plan-only "${OTP}"
  exit 0
fi

if [[ "${CONFIRM_DESTROY}" != "true" ]]; then
  echo "Refusing to destroy Hub without --yes. Run --plan-only first and review the plan." >&2
  exit 1
fi

"${SCRIPT_DIR}/destroy-hub-platform.sh" "${OTP}"
"${SCRIPT_DIR}/destroy-hub-infra.sh" --yes "${OTP}"

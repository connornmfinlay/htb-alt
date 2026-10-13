#!/usr/bin/env bash
# Source this to load AWS credentials into your shell *at runtime* from the
# tf-aws repo, WITHOUT ever copying them into this repo or into git:
#
#     source aws/env.sh
#
# The secrets stay in ~/tf-aws/secrets.auto.tfvars (which is gitignored there).
# Nothing here writes them to disk inside htb-alt.
set -euo pipefail

TF_AWS_DIR="${TF_AWS_DIR:-$HOME/tf-aws}"
SECRETS="$TF_AWS_DIR/secrets.auto.tfvars"

[ -f "$SECRETS" ] || { echo "[x] secrets file not found: $SECRETS" >&2; return 1 2>/dev/null || exit 1; }

# Extract the two HCL string values without echoing them.
_ak=$(sed -nE 's/^[[:space:]]*aws_access_key[[:space:]]*=[[:space:]]*"?([^"[:space:]]+)"?.*/\1/p' "$SECRETS")
_sk=$(sed -nE 's/^[[:space:]]*aws_secret_key[[:space:]]*=[[:space:]]*"?([^"[:space:]]+)"?.*/\1/p' "$SECRETS")

if [ -z "$_ak" ] || [ -z "$_sk" ]; then
  echo "[x] could not parse aws_access_key / aws_secret_key from $SECRETS" >&2
  return 1 2>/dev/null || exit 1
fi

export AWS_ACCESS_KEY_ID="$_ak"
export AWS_SECRET_ACCESS_KEY="$_sk"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
unset _ak _sk

echo "[+] AWS credentials loaded into this shell (region: $AWS_DEFAULT_REGION)"
echo "    identity check:  aws sts get-caller-identity"
echo "    FREE TIER ONLY - see aws/README.md and aws/guard.sh"

#!/usr/bin/env bash
# Free-tier guardrails for the AWS side of the lab.
#
#   aws/guard.sh check         list running instances + flag non-free-tier types
#   aws/guard.sh running       just show running instances
#   aws/guard.sh stop-all      stop every running instance (keeps disks)
#   aws/guard.sh launch-note   print the free-tier launch cheatsheet
#
# Requires credentials in the environment:  source aws/env.sh  first.
set -euo pipefail

# AWS Free Tier (12-month) compute allowance, as of 2026: 750 hrs/month of a
# t2.micro OR t3.micro (region-dependent). Stay on these for zero compute cost.
FREE_TIER_TYPES="t2.micro t3.micro"

command -v aws >/dev/null || { echo "[x] aws CLI not installed"; exit 1; }
: "${AWS_ACCESS_KEY_ID:?run 'source aws/env.sh' first}"

running() {
  aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,Name:Tags[?Key==`Name`]|[0].Value,AZ:Placement.AvailabilityZone}' \
    --output table
}

check() {
  echo "[*] Free-tier instance types: $FREE_TIER_TYPES"
  echo "[*] Running instances:"
  running
  local bad
  bad=$(aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query "Reservations[].Instances[?!contains(\`${FREE_TIER_TYPES// /\`,\`}\`, InstanceType)].InstanceId" \
    --output text 2>/dev/null || true)
  if [ -n "$bad" ]; then
    echo "[!] NON-free-tier instances running: $bad"
    echo "    stop them:  aws/guard.sh stop-all   (or terminate individually)"
  else
    echo "[+] no non-free-tier instances detected"
  fi
}

stop_all() {
  local ids
  ids=$(aws ec2 describe-instances --filters Name=instance-state-name,Values=running \
        --query 'Reservations[].Instances[].InstanceId' --output text)
  [ -z "$ids" ] && { echo "[*] nothing running"; return; }
  echo "[*] stopping: $ids"
  aws ec2 stop-instances --instance-ids $ids --output table
}

launch_note() {
  cat <<'EOF'
Free-tier EC2 launch cheatsheet
-------------------------------
  * instance type : t3.micro  (or t2.micro)  <- only these stay free
  * AMI           : Amazon Linux 2023 or Ubuntu LTS free-tier-eligible AMI
  * storage       : <= 30 GB gp3 EBS (free-tier EBS allowance)
  * one at a time : 750 hrs/month = ~1 instance running 24/7
  * STOP or TERMINATE when done:  aws/guard.sh stop-all
  * set a Budgets alarm at $1 so a mistake pages you, not bills you

The sibling tf-aws repo already defaults to t3.micro - reuse it, don't
hand-roll bigger instances. Launch intentionally-vulnerable cloud practice
only in an isolated VPC/security-group, never exposed to 0.0.0.0/0.
EOF
}

case "${1:-check}" in
  check) check ;;
  running) running ;;
  stop-all) stop_all ;;
  launch-note) launch_note ;;
  *) echo "usage: aws/guard.sh check|running|stop-all|launch-note"; exit 1 ;;
esac

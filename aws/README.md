# AWS / cloud pentest practice

Cloud penetration testing is its own interview topic, and your AWS account adds
a place to practise it. Two hard rules are wired into this module:

1. **Credentials never touch git.** They stay in `~/tf-aws/secrets.auto.tfvars`
   (gitignored there). `aws/env.sh` loads them into your shell at runtime only;
   nothing in this repo writes them to disk. The repo `.gitignore` also blocks
   `.env`, `*.tfstate`, `*.tfvars`, `.aws/`, keys and `credentials` as defence
   in depth.
2. **Free tier only.** `aws/guard.sh` enforces/checks `t2.micro` / `t3.micro`
   and helps you stop instances so nothing bills you.

## Load credentials

```bash
source aws/env.sh
aws sts get-caller-identity        # confirm you're the right account
```

## Stay inside the free tier

```bash
aws/guard.sh check         # list running instances, flag anything not free-tier
aws/guard.sh stop-all      # stop everything when you finish a session
aws/guard.sh launch-note   # free-tier launch cheatsheet
```

Set a **$1 AWS Budgets alarm** in the console as a backstop — a billing alert
is cheaper than a surprise invoice.

## What to practise (free-tier-friendly)

- **IAM enumeration & privilege-escalation paths** — mostly API calls, no
  compute cost. Great interview material and essentially free.
- **S3 / bucket permission misconfigurations** — storage-level, negligible cost.
- **Instance metadata & SSRF-to-cloud** — spin up a single `t3.micro`, practise,
  then `aws/guard.sh stop-all`.
- **Security-group / network exposure review** — API-level, free.

For a structured target set, deliberately-vulnerable AWS labs exist (e.g.
CloudGoat by Rhino Security Labs) that build scenarios with Terraform. If you
use one, confirm it pins to free-tier instance sizes before `terraform apply`,
and tear it down (`terraform destroy`) the moment you're done.

## Track it

A `cloud` module is in the tracker:

```bash
./tracker/track list cloud
```

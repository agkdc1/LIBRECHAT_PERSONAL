# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal LibreChat on GCP using Vertex AI (Gemini models). All infrastructure is Terraform. Cloudflare handles DNS, access control, and Host header rewriting via Worker.

## Architecture

```
Browser → Cloudflare Access (email gate) → Worker (Host rewrite + X-CF-Secret)
  → Cloud Run nginx sidecar (validates secret, 403 if missing)
  → LibreChat (localhost:3080) → MongoDB (VPC internal)

Terraform creates:
├── GCP Project + 8 APIs
├── Secret Manager (12 secrets: MongoDB creds, JWT keys, CF tokens, CF shared secret)
├── VPC (main + cloudrun subnets, firewall rules)
├── GCE e2-micro — MongoDB 7 with auth + custom port + keyfile
├── Cloud Run v2 — two containers:
│   ├── nginx-proxy (ingress, port 8080) — validates X-CF-Secret header
│   ├── librechat (sidecar, port 3080) — the app
│   ├── VPC egress → MongoDB internal IP
│   └── SA with aiplatform.user (Vertex AI via ADC)
├── Artifact Registry — remote repo proxying ghcr.io
├── Cloudflare Worker + DNS CNAME + Access Application
└── GCS bucket (public, static assets)
```

## Commands

```bash
terraform init

# Apply (need sudo to read token file owned by root; GOOGLE_OAUTH_ACCESS_TOKEN for GCP auth)
CF_TOKEN=$(sudo cat /root/cloudflare) && GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token) terraform apply -var="cloudflare_api_token=$CF_TOKEN"

# Destroy
CF_TOKEN=$(sudo cat /root/cloudflare) && GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token) terraform destroy -var="cloudflare_api_token=$CF_TOKEN"

# SSH into MongoDB VM
gcloud compute ssh mongodb --zone=us-central1-a --tunnel-through-iap --project=librechat-c9d71093
```

## Sensitive Values

All in `terraform.tfvars` (gitignored): `project_id`, `billing_account`, `owner_email`, `custom_domain`. Cloudflare tokens passed via CLI `-var` flags.

## Key Files

- `cloudflare.tf` — Worker (Host rewrite + shared secret injection), DNS, Access app + policy
- `cloudrun.tf` — Cloud Run with nginx auth proxy sidecar + LibreChat app
- `compute.tf` — MongoDB VM + service account
- `scripts/mongodb-startup.sh` — installs MongoDB, fetches secrets from SM, configures auth
- `secrets.tf` — random value generators + Secret Manager secrets
- `librechat.yaml` — Gemini model configuration (models, token limits)
- `artifact_registry.tf` — ghcr.io remote repository for Cloud Run

## Security: Shared Secret (Cloud Run origin validation)

Cloud Run stays public (`INGRESS_TRAFFIC_ALL` + `allUsers` invoker) but an nginx sidecar validates that every request carries the correct `X-CF-Secret` header. The Cloudflare Worker injects this header; direct `.run.app` access without it gets 403.

Cloud Run v2 with `launch_stage = "BETA"` for multi-container (sidecar) support:
- `secrets.tf` — `random_password.cf_shared_secret` (64 chars) + Secret Manager entry
- `cloudflare.tf` — Worker injects `X-CF-Secret` header on every proxied request
- `cloudrun.tf` — nginx sidecar validates the header, returns 403 if missing/wrong, strips it before forwarding to LibreChat
  - `librechat` container: sidecar (no ingress port), `startup_probe` on TCP 3080
  - `nginx-proxy` container: ingress on port 8080, `map_hash_bucket_size 128` (required for 64-char secret), `depends_on` librechat
  - WebSocket support via `Upgrade` + `Connection` proxy headers

**Notes:**
- Cloud Run pulls `docker.io/library/nginx:alpine` — if Docker Hub rate-limits, add a Docker Hub remote repo to Artifact Registry
- `cloudflare_rule_token` variable/secret is unused (Origin Rules replaced by Worker); secret version is skipped when empty

## Cost

$0/month for personal use (all within GCP + Cloudflare free tiers).

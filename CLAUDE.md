# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Self-hosted LibreChat on GCP using Vertex AI (Gemini models). All infrastructure is managed by Terraform. Cloudflare handles DNS, tunneling, and access control.

## Architecture

```
Browser → Cloudflare Access (email gate) → Cloudflare Tunnel
  → cloudflared on MongoDB VM → Cloud Run (.run.app)

Terraform creates:
├── GCP Project + APIs (Vertex AI, Compute, Run, SM, Storage)
├── Secret Manager (MongoDB creds, JWT secrets, CF token, tunnel token)
├── VPC (main subnet + cloudrun subnet, firewall rules)
├── GCE e2-micro (us-central1, free tier)
│   ├── MongoDB 7 — auth + custom port + keyfile
│   └── cloudflared — Cloudflare Tunnel connector
├── Cloud Run v2 (us-central1)
│   ├── LibreChat container
│   ├── VPC egress → MongoDB via internal IP
│   └── SA with aiplatform.user (Vertex AI via ADC)
├── Cloudflare Tunnel + DNS CNAME + Access Application
│   └── Only owner_email can access (email-verified)
└── GCS bucket (public, for static assets)
```

## Commands

```bash
terraform init
terraform plan -var="cloudflare_api_token=$(cat /root/cloudflare)"
terraform apply -var="cloudflare_api_token=$(cat /root/cloudflare)"
terraform destroy -var="cloudflare_api_token=$(cat /root/cloudflare)"

# SSH into MongoDB VM
gcloud compute ssh mongodb --zone=us-central1-a --tunnel-through-iap --project=<PROJECT_ID>
```

## Sensitive Values

All in `terraform.tfvars` (gitignored): `project_id`, `owner_email`, `custom_domain`. Cloudflare token passed via CLI `-var` flag from `/root/cloudflare`.

All runtime secrets stored in GCP Secret Manager. Never hardcode credentials in .tf files.

## Key Files

- `cloudflare.tf` — Tunnel, DNS, Access application + policy
- `cloudrun.tf` — LibreChat on Cloud Run with VPC egress
- `compute.tf` — MongoDB VM (also runs cloudflared)
- `scripts/mongodb-startup.sh` — installs MongoDB + cloudflared, fetches secrets from SM
- `secrets.tf` — all Secret Manager secrets + random value generators
- `librechat.yaml` — Gemini model configuration

## Cost

Effectively free tier for personal use:
- e2-micro VM + 30GB disk + static IP: free tier
- Cloud Run (max 1 instance): free tier for low usage
- Cloudflare Access + Tunnel: free
- Secret Manager: free tier

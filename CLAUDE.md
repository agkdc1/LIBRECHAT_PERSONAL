# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal LibreChat on GCP using Vertex AI (Gemini models). All infrastructure is Terraform. Cloudflare handles DNS, access control, and Host header rewriting via Worker.

## Architecture

```
Browser → Cloudflare Access (email gate) → Worker (Host rewrite)
  → Cloud Run (.run.app) → MongoDB (VPC internal)

Terraform creates:
├── GCP Project + 8 APIs
├── Secret Manager (11 secrets: MongoDB creds, JWT keys, CF tokens)
├── VPC (main + cloudrun subnets, firewall rules)
├── GCE e2-micro — MongoDB 7 with auth + custom port + keyfile
├── Cloud Run v2 — LibreChat via Artifact Registry ghcr.io proxy
│   ├── VPC egress → MongoDB internal IP
│   └── SA with aiplatform.user (Vertex AI via ADC)
├── Artifact Registry — remote repo proxying ghcr.io
├── Cloudflare Worker + DNS CNAME + Access Application
└── GCS bucket (public, static assets)
```

## Commands

```bash
terraform init
terraform apply -var="cloudflare_api_token=$(cat /root/cloudflare)"
terraform destroy -var="cloudflare_api_token=$(cat /root/cloudflare)"

# SSH into MongoDB VM
gcloud compute ssh mongodb --zone=us-central1-a --tunnel-through-iap --project=<PROJECT_ID>
```

## Sensitive Values

All in `terraform.tfvars` (gitignored): `project_id`, `billing_account`, `owner_email`, `custom_domain`. Cloudflare tokens passed via CLI `-var` flags.

## Key Files

- `cloudflare.tf` — Worker (Host rewrite), DNS, Access app + policy
- `cloudrun.tf` — LibreChat on Cloud Run with VPC egress
- `compute.tf` — MongoDB VM + service account
- `scripts/mongodb-startup.sh` — installs MongoDB, fetches secrets from SM, configures auth
- `secrets.tf` — random value generators + Secret Manager secrets
- `librechat.yaml` — Gemini model configuration (models, token limits)
- `artifact_registry.tf` — ghcr.io remote repository for Cloud Run

## Cost

$0/month for personal use (all within GCP + Cloudflare free tiers).

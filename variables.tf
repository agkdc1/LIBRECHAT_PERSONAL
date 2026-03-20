variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "project_name" {
  description = "GCP project display name"
  type        = string
  default     = "LibreChat"
}

variable "billing_account" {
  description = "GCP billing account ID"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone (must be in var.region, us-central1-* for free tier)"
  type        = string
  default     = "us-central1-a"
}

variable "owner_email" {
  description = "Owner email — only this Google account can access LibreChat via Cloudflare Access"
  type        = string
  sensitive   = true
}

variable "custom_domain" {
  description = "Custom domain for LibreChat (e.g. chat.example.com)"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token — pass via: -var='cloudflare_api_token=<token>'"
  type        = string
  sensitive   = true
}

variable "cloudflare_rule_token" {
  description = "Cloudflare API token with Transform Rules edit — pass via: -var='cloudflare_rule_token=<token>'"
  type        = string
  sensitive   = true
  default     = ""
}

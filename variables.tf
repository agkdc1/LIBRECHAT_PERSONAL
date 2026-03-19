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
  default     = "01379E-748455-3FDDAA"
}

variable "region" {
  description = "GCP region for Vertex AI"
  type        = string
  default     = "us-central1"
}

output "project_id" {
  description = "GCP project ID for Vertex AI"
  value       = google_project.this.project_id
}

output "service_account_email" {
  description = "Service account for Vertex AI"
  value       = google_service_account.librechat.email
}

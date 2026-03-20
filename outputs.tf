output "project_id" {
  description = "GCP project ID"
  value       = google_project.this.project_id
}

output "mongodb_internal_ip" {
  description = "MongoDB VM internal IP (used by Cloud Run)"
  value       = google_compute_instance.mongodb.network_interface[0].network_ip
}

output "mongodb_external_ip" {
  description = "MongoDB VM external IP"
  value       = google_compute_address.mongodb.address
}

output "mongodb_port" {
  description = "MongoDB custom port"
  value       = random_integer.mongodb_port.result
  sensitive   = true
}

output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.librechat.uri
}

output "frontend_bucket" {
  description = "Public GCS bucket for static assets"
  value       = google_storage_bucket.frontend.url
}

output "ssh_command" {
  description = "SSH into MongoDB VM via IAP tunnel"
  value       = "gcloud compute ssh mongodb --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

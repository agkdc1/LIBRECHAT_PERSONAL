# ─── VPC Network ─────────────────────────────────────────────────────────────

resource "google_compute_network" "this" {
  name                    = "librechat-vpc"
  project                 = google_project.this.project_id
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis["compute.googleapis.com"]]
}

resource "google_compute_subnetwork" "main" {
  name          = "main"
  project       = google_project.this.project_id
  network       = google_compute_network.this.id
  region        = var.region
  ip_cidr_range = "10.0.0.0/24"
}

resource "google_compute_subnetwork" "cloudrun" {
  name          = "cloudrun"
  project       = google_project.this.project_id
  network       = google_compute_network.this.id
  region        = var.region
  ip_cidr_range = "10.0.1.0/24"
}

# ─── Static IP ───────────────────────────────────────────────────────────────

# Regional static IP for MongoDB VM (free while VM is running)
resource "google_compute_address" "mongodb" {
  name    = "mongodb-ip"
  project = google_project.this.project_id
  region  = var.region
}

# ─── Firewall Rules ──────────────────────────────────────────────────────────

# SSH via IAP tunnel only
resource "google_compute_firewall" "iap_ssh" {
  name    = "allow-iap-ssh"
  project = google_project.this.project_id
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["mongodb"]
}

# MongoDB: only from Cloud Run subnet (internal traffic)
resource "google_compute_firewall" "mongodb_internal" {
  name    = "allow-mongodb-internal"
  project = google_project.this.project_id
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = [tostring(random_integer.mongodb_port.result)]
  }

  source_ranges = [google_compute_subnetwork.cloudrun.ip_cidr_range]
  target_tags   = ["mongodb"]
}

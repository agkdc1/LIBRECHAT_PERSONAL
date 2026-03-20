# ─── MongoDB Service Account ─────────────────────────────────────────────────

resource "google_service_account" "mongodb" {
  account_id   = "mongodb-sa"
  display_name = "MongoDB VM SA"
  project      = google_project.this.project_id
  depends_on   = [google_project_service.apis["iam.googleapis.com"]]
}

resource "google_project_iam_member" "mongodb_secret_accessor" {
  project = google_project.this.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.mongodb.email}"
}

resource "google_project_iam_member" "mongodb_log_writer" {
  project = google_project.this.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.mongodb.email}"
}

# ─── MongoDB GCE Instance (e2-micro free tier) ──────────────────────────────
#
# Also runs cloudflared for the Cloudflare Tunnel (connects to Cloud Run).
#

resource "google_compute_instance" "mongodb" {
  name         = "mongodb"
  project      = google_project.this.project_id
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = ["mongodb"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 30 # free tier: 30GB standard PD
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.this.id
    subnetwork = google_compute_subnetwork.main.id
    access_config {
      nat_ip = google_compute_address.mongodb.address
    }
  }

  service_account {
    email  = google_service_account.mongodb.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = file("${path.module}/scripts/mongodb-startup.sh")

  depends_on = [
    google_project_service.apis["compute.googleapis.com"],
    google_secret_manager_secret_version.mongodb_password,
    google_secret_manager_secret_version.mongodb_port,
    google_secret_manager_secret_version.mongodb_auth_key,
    google_project_iam_member.mongodb_secret_accessor,
  ]
}

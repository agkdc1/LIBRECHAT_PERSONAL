# ─── Public GCS bucket for frontend static assets / image uploads ────────────

resource "google_storage_bucket" "frontend" {
  name     = "${google_project.this.project_id}-frontend"
  project  = google_project.this.project_id
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }

  cors {
    origin          = ["https://${var.custom_domain}"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }

  depends_on = [google_project_service.apis["storage.googleapis.com"]]
}

resource "google_storage_bucket_iam_member" "public" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

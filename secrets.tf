# ─── Random values ───────────────────────────────────────────────────────────

resource "random_password" "mongodb" {
  length  = 32
  special = false # alphanumeric only — avoids URL-encoding in connection string
}

resource "random_integer" "mongodb_port" {
  min = 30000
  max = 60000
}

resource "random_id" "mongodb_keyfile" {
  byte_length = 756
}

resource "random_id" "creds_key" {
  byte_length = 32 # 64 hex chars for LibreChat CREDS_KEY
}

resource "random_id" "creds_iv" {
  byte_length = 16 # 32 hex chars for LibreChat CREDS_IV
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "random_password" "jwt_refresh_secret" {
  length  = 64
  special = false
}

# ─── Secret Manager ──────────────────────────────────────────────────────────

resource "google_secret_manager_secret" "mongodb_password" {
  secret_id = "mongodb-password"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "mongodb_password" {
  secret      = google_secret_manager_secret.mongodb_password.id
  secret_data = random_password.mongodb.result
}

resource "google_secret_manager_secret" "mongodb_port" {
  secret_id = "mongodb-port"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "mongodb_port" {
  secret      = google_secret_manager_secret.mongodb_port.id
  secret_data = tostring(random_integer.mongodb_port.result)
}

resource "google_secret_manager_secret" "mongodb_auth_key" {
  secret_id = "mongodb-auth-key"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "mongodb_auth_key" {
  secret      = google_secret_manager_secret.mongodb_auth_key.id
  secret_data = random_id.mongodb_keyfile.b64_std
}

resource "google_secret_manager_secret" "cloudflare_token" {
  secret_id = "cloudflare-api-token"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "cloudflare_token" {
  secret      = google_secret_manager_secret.cloudflare_token.id
  secret_data = var.cloudflare_api_token
}

resource "google_secret_manager_secret" "cloudflare_rule_token" {
  secret_id = "cloudflare-rule-token"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "cloudflare_rule_token" {
  secret      = google_secret_manager_secret.cloudflare_rule_token.id
  secret_data = var.cloudflare_rule_token
}

resource "google_secret_manager_secret" "mongodb_uri" {
  secret_id = "mongodb-uri"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "mongodb_uri" {
  secret      = google_secret_manager_secret.mongodb_uri.id
  secret_data = "mongodb://admin:${random_password.mongodb.result}@${google_compute_instance.mongodb.network_interface[0].network_ip}:${random_integer.mongodb_port.result}/librechat?authSource=admin"
}

resource "google_secret_manager_secret" "creds_key" {
  secret_id = "creds-key"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "creds_key" {
  secret      = google_secret_manager_secret.creds_key.id
  secret_data = random_id.creds_key.hex
}

resource "google_secret_manager_secret" "creds_iv" {
  secret_id = "creds-iv"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "creds_iv" {
  secret      = google_secret_manager_secret.creds_iv.id
  secret_data = random_id.creds_iv.hex
}

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "jwt-secret"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.jwt_secret.result
}

resource "google_secret_manager_secret" "jwt_refresh_secret" {
  secret_id = "jwt-refresh-secret"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "jwt_refresh_secret" {
  secret      = google_secret_manager_secret.jwt_refresh_secret.id
  secret_data = random_password.jwt_refresh_secret.result
}

resource "google_secret_manager_secret" "librechat_config" {
  secret_id = "librechat-config"
  project   = google_project.this.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "librechat_config" {
  secret      = google_secret_manager_secret.librechat_config.id
  secret_data = file("${path.module}/librechat.yaml")
}

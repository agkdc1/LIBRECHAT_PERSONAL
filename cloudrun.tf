# ─── Cloud Run Service Account ───────────────────────────────────────────────

resource "google_service_account" "cloudrun" {
  account_id   = "cloudrun-sa"
  display_name = "Cloud Run LibreChat SA"
  project      = google_project.this.project_id
  depends_on   = [google_project_service.apis["iam.googleapis.com"]]
}

resource "google_project_iam_member" "cloudrun_vertex_ai" {
  project = google_project.this.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

resource "google_project_iam_member" "cloudrun_secret_accessor" {
  project = google_project.this.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

# ─── nginx proxy config (validates Cloudflare shared secret) ────────────────

locals {
  nginx_proxy_conf = <<-NGINX
    map_hash_bucket_size 128;
    map $http_x_cf_secret $cf_auth {
        "${random_password.cf_shared_secret.result}" 1;
        default     0;
    }
    server {
        listen 8080;
        location / {
            if ($cf_auth = 0) {
                return 403;
            }
            proxy_pass http://127.0.0.1:3080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-CF-Secret "";
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
  NGINX
}

# ─── Cloud Run Service ───────────────────────────────────────────────────────
#
# Ingress: all traffic — nginx sidecar validates X-CF-Secret header.
# Requests without the shared secret (i.e. direct .run.app access) get 403.
#

resource "google_cloud_run_v2_service" "librechat" {
  name     = "librechat"
  project  = google_project.this.project_id
  location = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false
  launch_stage        = "BETA"

  template {
    service_account = google_service_account.cloudrun.email

    scaling {
      min_instance_count = 0
      max_instance_count = 1 # cost control
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.this.id
        subnetwork = google_compute_subnetwork.cloudrun.id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    # ── LibreChat app (sidecar — no ingress port) ──

    containers {
      name  = "librechat"
      image = "${var.region}-docker.pkg.dev/${google_project.this.project_id}/${google_artifact_registry_repository.ghcr.repository_id}/danny-avila/librechat-dev:latest"

      # Write config file from base64 env var, then start the app
      command = ["/bin/sh", "-c"]
      args    = ["printf '%s' \"$LIBRECHAT_YAML_B64\" | base64 -d > /app/librechat.yaml && exec npm run backend"]

      # ── Config file (base64-encoded) ──

      env {
        name  = "LIBRECHAT_YAML_B64"
        value = base64encode(file("${path.module}/librechat.yaml"))
      }

      # ── App settings ──

      env {
        name  = "HOST"
        value = "0.0.0.0"
      }

      env {
        name  = "ALLOW_REGISTRATION"
        value = "false"
      }

      env {
        name  = "ALLOW_SOCIAL_LOGIN"
        value = "false"
      }

      # Vertex AI: GOOGLE_KEY must be unset so LibreChat loads the service key file
      # and detects project_id → switches to Vertex AI provider
      env {
        name = "GOOGLE_SERVICE_KEY_FILE"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.cloudrun_sa_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "GOOGLE_LOC"
        value = "global" # Gemini 3.x preview models require location "global", not a region
      }

      # Domain URLs (sensitive var, not in git — only in tfvars + GCP runtime)
      env {
        name  = "DOMAIN_CLIENT"
        value = "https://${var.custom_domain}"
      }

      env {
        name  = "DOMAIN_SERVER"
        value = "https://${var.custom_domain}"
      }

      # ── Secrets from Secret Manager ──

      env {
        name = "MONGO_URI"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.mongodb_uri.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "CREDS_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.creds_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "CREDS_IV"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.creds_iv.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_REFRESH_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_refresh_secret.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        tcp_socket {
          port = 3080
        }
        initial_delay_seconds = 0
        period_seconds        = 5
        failure_threshold     = 12
        timeout_seconds       = 3
      }
    }

    # ── nginx auth proxy (ingress container) ──

    containers {
      name  = "nginx-proxy"
      image = "docker.io/library/nginx:alpine"

      ports {
        container_port = 8080
      }

      command = ["/bin/sh", "-c"]
      args    = ["printf '%s' \"$NGINX_CONF_B64\" | base64 -d > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]

      env {
        name  = "NGINX_CONF_B64"
        value = base64encode(local.nginx_proxy_conf)
      }

      resources {
        limits = {
          cpu    = "0.5"
          memory = "128Mi"
        }
      }

      depends_on = ["librechat"]
    }
  }

  depends_on = [
    google_project_service.apis["run.googleapis.com"],
    google_secret_manager_secret_version.mongodb_uri,
    google_secret_manager_secret_version.creds_key,
    google_secret_manager_secret_version.creds_iv,
    google_secret_manager_secret_version.jwt_secret,
    google_secret_manager_secret_version.jwt_refresh_secret,
    google_secret_manager_secret_version.cloudrun_sa_key,
  ]
}

# Allow unauthenticated invocation — nginx sidecar validates the shared secret
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = google_project.this.project_id
  location = var.region
  name     = google_cloud_run_v2_service.librechat.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

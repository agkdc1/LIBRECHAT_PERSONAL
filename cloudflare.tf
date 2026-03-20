# ─── Cloudflare Zone Lookup ───────────────────────────────────────────────────

locals {
  domain_parts = split(".", var.custom_domain)
  zone_name    = join(".", slice(local.domain_parts, 1, length(local.domain_parts)))
  subdomain    = local.domain_parts[0]
}

data "cloudflare_zone" "this" {
  name = local.zone_name
}

# ─── DNS: proxied CNAME to Cloud Run ────────────────────────────────────────

resource "cloudflare_record" "librechat" {
  zone_id = data.cloudflare_zone.this.id
  name    = local.subdomain
  type    = "CNAME"
  content = trimprefix(google_cloud_run_v2_service.librechat.uri, "https://")
  proxied = true
}

# ─── Cloudflare Worker: rewrite Host header for Cloud Run ────────────────────
#
# Free plan doesn't support Origin Rules host_header override.
# Worker rewrites the Host header so Cloud Run routes correctly.
# Free tier: 100K requests/day.
#

resource "cloudflare_workers_script" "proxy" {
  account_id = data.cloudflare_zone.this.account_id
  name       = "librechat-proxy"
  content    = <<-JS
    export default {
      async fetch(request) {
        const url = new URL(request.url);
        url.hostname = "${trimprefix(google_cloud_run_v2_service.librechat.uri, "https://")}";
        const newReq = new Request(url, request);
        newReq.headers.set("X-CF-Secret", "${random_password.cf_shared_secret.result}");
        return fetch(newReq);
      }
    };
  JS
  compatibility_date = "2024-01-01"
  module             = true
}

resource "cloudflare_workers_route" "proxy" {
  zone_id     = data.cloudflare_zone.this.id
  pattern     = "${var.custom_domain}/*"
  script_name = cloudflare_workers_script.proxy.name
}

# ─── Cloudflare Access (Google login, owner-only, $0) ───────────────────────

resource "cloudflare_zero_trust_access_application" "librechat" {
  zone_id          = data.cloudflare_zone.this.id
  name             = "LibreChat"
  domain           = var.custom_domain
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "owner_only" {
  zone_id        = data.cloudflare_zone.this.id
  application_id = cloudflare_zero_trust_access_application.librechat.id
  name           = "Owner only"
  precedence     = 1
  decision       = "allow"

  include {
    email = [var.owner_email]
  }
}

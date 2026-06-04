terraform {
  required_version = ">= 1.5.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# ── R2 bucket ──────────────────────────────────────────────────────────────

resource "cloudflare_r2_bucket" "assets" {
  account_id = var.cloudflare_account_id
  name       = var.bucket_name
  location   = var.jurisdiction
}

# ── CORS ───────────────────────────────────────────────────────────────────

resource "cloudflare_r2_bucket_cors" "assets" {
  account_id = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.assets.name

  rules = [
    {
      allowed_origins = var.allowed_origins
      allowed_methods = ["GET", "HEAD"]
      allowed_headers = ["*"]
      max_age_seconds = 86400
    }
  ]
}

# ── Custom domain CNAME ────────────────────────────────────────────────────

resource "cloudflare_record" "assets_cdn" {
  count   = var.cdn_subdomain != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = var.cdn_subdomain
  type    = "CNAME"
  content = "${cloudflare_r2_bucket.assets.name}.${var.cloudflare_account_id}.r2.cloudflarestorage.com"
  proxied = true
  ttl     = 1 # auto when proxied
}

# ── Transform Rules: AI crawler signals ───────────────────────────────────

resource "cloudflare_ruleset" "ai_signals" {
  count   = var.cdn_subdomain != "" && var.enable_ai_signals ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "R2 asset AI crawler signals"
  phase   = "http_response_headers_transform"
  kind    = "zone"

  rules {
    description = "Set AI crawler headers on R2 asset CDN"
    expression  = "(http.host eq \"${var.cdn_subdomain}.${var.domain}\")"
    action      = "rewrite"
    enabled     = true

    action_parameters {
      headers {
        name      = "X-Robots-Tag"
        operation = "set"
        value     = "noai, noimageai"
      }
      headers {
        name      = "X-TDM-Reservation"
        operation = "set"
        value     = "1"
      }
      headers {
        name      = "Content-Signal"
        operation = "set"
        value     = var.content_signal
      }
    }
  }
}

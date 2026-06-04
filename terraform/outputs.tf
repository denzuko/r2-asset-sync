output "bucket_name" {
  description = "R2 bucket name"
  value       = cloudflare_r2_bucket.assets.name
}

output "s3_endpoint" {
  description = "R2 S3-compatible endpoint URL for use with r2_sync.sh"
  value       = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
}

output "cdn_domain" {
  description = "Full CDN domain (cdn_subdomain.domain) — empty if cdn_subdomain not set"
  value       = var.cdn_subdomain != "" ? "${var.cdn_subdomain}.${var.domain}" : ""
}

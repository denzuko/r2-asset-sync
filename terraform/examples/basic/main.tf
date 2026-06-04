module "r2_assets" {
  source = "../../"

  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id
  bucket_name           = "assets-cdn-example-com"
  allowed_origins       = ["https://example.com"]
  domain                = "example.com"
  cdn_subdomain         = "assets.cdn"
  jurisdiction          = "ENAM"
  enable_ai_signals     = true
}

# Pass outputs to r2_sync.sh:
# R2_ACCOUNT_ID = var.cloudflare_account_id
# R2_BUCKET     = module.r2_assets.bucket_name
# CDN_DOMAIN    = module.r2_assets.cdn_domain
output "r2_sync_env" {
  description = "Environment variables for r2_sync.sh"
  value = {
    R2_BUCKET  = module.r2_assets.bucket_name
    CDN_DOMAIN = module.r2_assets.cdn_domain
    endpoint   = module.r2_assets.s3_endpoint
  }
}

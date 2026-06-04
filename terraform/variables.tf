variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain. Required when cdn_subdomain is set."
  type        = string
  default     = ""
  sensitive   = true
}

variable "bucket_name" {
  description = "R2 bucket name (e.g. assets-cdn-example-com)"
  type        = string
}

variable "jurisdiction" {
  description = "R2 storage jurisdiction. Cannot be changed after creation. Recommended: ENAM (Eastern North America) or WEUR."
  type        = string
  default     = "ENAM"

  validation {
    condition     = contains(["ENAM", "WEUR", "APAC"], var.jurisdiction)
    error_message = "jurisdiction must be one of: ENAM, WEUR, APAC"
  }
}

variable "allowed_origins" {
  description = "CORS allowed origins (e.g. [\"https://example.com\"])"
  type        = list(string)
}

variable "domain" {
  description = "Root domain (e.g. example.com). Used to construct the full CDN hostname."
  type        = string
  default     = ""
}

variable "cdn_subdomain" {
  description = "CDN subdomain prefix (e.g. assets.cdn). Full domain becomes cdn_subdomain.domain."
  type        = string
  default     = ""
}

variable "enable_ai_signals" {
  description = "Create a Transform Rule to add X-Robots-Tag, X-TDM-Reservation, and Content-Signal headers."
  type        = bool
  default     = true
}

variable "content_signal" {
  description = "Content-Signal header value."
  type        = string
  default     = "ai-train=no; search=no"
}

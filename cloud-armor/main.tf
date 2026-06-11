terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "gcp-security-project-498707"
  region  = "us-central1"
}

# Cloud Armor security policy
resource "google_compute_security_policy" "waf_policy" {
  name        = "waf-security-policy"
  description = "WAF policy blocking SQLi, XSS and DDoS"

  # Rule 1 - Block SQL injection attacks
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "Block SQL injection attacks"
  }

  # Rule 2 - Block Cross Site Scripting attacks
  rule {
    action   = "deny(403)"
    priority = "1001"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "Block XSS attacks"
  }

  # Rule 3 - Block Local File Inclusion attacks
  rule {
    action   = "deny(403)"
    priority = "1002"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-stable')"
      }
    }
    description = "Block LFI attacks"
  }

  # Rule 4 - Rate limiting - block IPs making more than 100 requests per minute
  rule {
    action   = "throttle"
    priority = "2000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Rate limit to prevent DDoS"
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
    }
  }

  # Default rule - allow all other traffic
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }
}

# A simple backend bucket to act as our app target
resource "google_compute_backend_bucket" "app_backend" {
  name        = "app-backend-bucket"
  bucket_name = google_storage_bucket.app_bucket.name
  enable_cdn  = false
}

# GCS bucket as dummy app
# resource "google_storage_bucket" "app_bucket" {
#   name     = "gcp-security-app-bucket-498707"
#   location = "US"

#   uniform_bucket_level_access = true
# }
resource "google_storage_bucket" "app_bucket" {
  name                        = "gcp-security-app-bucket-498707"
  location                    = "US"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  logging {
    log_bucket = "gcp-security-app-bucket-498707-logs"
  }
}

# URL map - routes traffic to backend
resource "google_compute_url_map" "url_map" {
  name            = "security-url-map"
  default_service = google_compute_backend_bucket.app_backend.self_link
}

# HTTP proxy
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "security-http-proxy"
  url_map = google_compute_url_map.url_map.self_link
}

# Global forwarding rule - this is the actual load balancer frontend
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "security-forwarding-rule"
  target     = google_compute_target_http_proxy.http_proxy.self_link
  port_range = "80"
  ip_protocol = "TCP"
}
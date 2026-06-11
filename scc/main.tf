terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project       = "gcp-security-project-498707"
  region        = "us-central1"
  user_project_override = true
  billing_project       = "gcp-security-project-498707"
}

# Enable SCC notifications - sends findings to Pub/Sub
resource "google_scc_v2_organization_notification_config" "scc_notifications" {
  config_id    = "scc-notify"
  organization = var.org_id
  location     = "global"
  description  = "SCC findings notification to Pub/Sub"
  pubsub_topic = google_pubsub_topic.scc_findings.id

  streaming_config {
    filter = "state = \"ACTIVE\""
  }
}

# Pub/Sub topic to receive SCC findings
resource "google_pubsub_topic" "scc_findings" {
  name = "scc-findings-topic"
}

variable "org_id" {
  description = "GCP Organization ID"
  type        = string
}
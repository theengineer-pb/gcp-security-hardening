terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project               = "gcp-security-project-498707"
  region                = "us-central1"
  user_project_override = true
  billing_project       = "gcp-security-project-498707"
}

# Service account for reading SCC findings
resource "google_service_account" "scc_reader" {
  account_id   = "scc-reader-sa"
  display_name = "SCC Findings Reader"
  description  = "Reads Security Command Center findings only"
}

# Service account for Pub/Sub publishing
resource "google_service_account" "pubsub_publisher" {
  account_id   = "pubsub-publisher-sa"
  display_name = "PubSub Publisher"
  description  = "Publishes messages to Pub/Sub topic only"
}

# Service account for Cloud Function execution
resource "google_service_account" "function_sa" {
  account_id   = "function-sa"
  display_name = "Cloud Function Service Account"
  description  = "Used by Cloud Function to revoke compromised IAM keys"
}

# Give scc-reader-sa only SCC findings viewer role
resource "google_organization_iam_member" "scc_reader_role" {
  org_id = "351850089863"
  role   = "roles/securitycenter.findingsViewer"
  member = "serviceAccount:${google_service_account.scc_reader.email}"
}

# Give pubsub-publisher-sa only Pub/Sub publisher role
resource "google_project_iam_member" "pubsub_publisher_role" {
  project = "gcp-security-project-498707"
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.pubsub_publisher.email}"
}

# Give function-sa only the role needed to revoke IAM access
resource "google_project_iam_member" "function_sa_role" {
  project = "gcp-security-project-498707"
  role    = "roles/iam.securityAdmin"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Give function-sa ability to read Pub/Sub messages
resource "google_project_iam_member" "function_pubsub_role" {
  project = "gcp-security-project-498707"
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}
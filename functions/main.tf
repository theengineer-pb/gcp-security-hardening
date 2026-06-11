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

# Zip the function code for deployment
data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/threat-response"
  output_path = "${path.module}/threat-response.zip"
}

# Storage bucket to hold the function code
# resource "google_storage_bucket" "function_bucket" {
#   name     = "gcp-security-functions-498707"
#   location = "US"
#   uniform_bucket_level_access = true
# }
resource "google_storage_bucket" "function_bucket" {
  name                        = "gcp-security-functions-498707"
  location                    = "US"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  logging {
    log_bucket = "gcp-security-functions-498707-logs"
  }
}


# Upload zipped function code to bucket
resource "google_storage_bucket_object" "function_code" {
  name   = "threat-response-${data.archive_file.function_zip.output_md5}.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = data.archive_file.function_zip.output_path
}

# The Cloud Function itself
resource "google_cloudfunctions_function" "threat_response" {
  name        = "threat-response-function"
  description = "Automatically responds to SCC threat findings"
  runtime     = "python311"
  region      = "us-central1"
  ingress_settings = "ALLOW_INTERNAL_ONLY"    # ADDED THIS LINE

  # Point to the uploaded code
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.function_code.name

  # Function entry point - must match function name in main.py
  entry_point = "respond_to_threat"

  # Trigger - fires when a message arrives on Pub/Sub topic
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "projects/gcp-security-project-498707/topics/scc-findings-topic"
  }

  # Use the least privilege service account we created in Phase 5
  service_account_email = "function-sa@gcp-security-project-498707.iam.gserviceaccount.com"

  # Function configuration
  available_memory_mb   = 256
  timeout               = 60
  max_instances         = 10

  environment_variables = {
    PROJECT_ID = "gcp-security-project-498707"
  }
}
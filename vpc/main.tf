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

# Create custom VPC - no auto subnets (more secure)
resource "google_compute_network" "secure_vpc" {
  name                    = "secure-vpc"
  auto_create_subnetworks = false
  description             = "Custom VPC with manual subnet control"
}

# Create a private subnet
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.secure_vpc.id
  private_ip_google_access = true    # ADD THIS LINE

  # Enable flow logs - important for security monitoring
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Firewall rule - allow only HTTPS (443) from internet
resource "google_compute_firewall" "allow_https" {
  name    = "allow-https-inbound"
  network = google_compute_network.secure_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
  description   = "Allow HTTPS traffic from internet to web servers only"
}

# Firewall rule - allow SSH only from specific IP (your IP)
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-restricted"
  network = google_compute_network.secure_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Restricts SSH to your IP only - not open to world
  source_ranges = ["49.36.144.202/32"]
  target_tags   = ["ssh-allowed"]
  description   = "SSH restricted to admin IP only"
}

# Firewall rule - deny all other inbound traffic explicitly
resource "google_compute_firewall" "deny_all_ingress" {
  name     = "deny-all-ingress"
  network  = google_compute_network.secure_vpc.name
  priority = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Deny all other inbound traffic"
}
# terraform/modules/vpc/main.tf

# 1. The Global VPC Network
resource "google_compute_network" "main" {
  name                    = "gke-multi-region-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false # We want custom subnets, not default ones
}

# 2. Subnet for the Primary Region
resource "google_compute_subnetwork" "primary" {
  name          = "gke-subnet-primary"
  project       = var.project_id
  region        = var.primary_region
  network       = google_compute_network.main.id
  ip_cidr_range = "10.0.0.0/16" 
}

# 3. Subnet for the Secondary Region
resource "google_compute_subnetwork" "secondary" {
  name          = "gke-subnet-secondary"
  project       = var.project_id
  region        = var.secondary_region
  network       = google_compute_network.main.id
  ip_cidr_range = "10.1.0.0/16"
}

# 4. Firewall Rule for Internal Node Communication
resource "google_compute_firewall" "allow_internal" {
  name    = "gke-allow-internal"
  project = var.project_id
  network = google_compute_network.main.name

  allow {
    protocol = "all" # Allow all internal communication
  }

  # Apply this rule to nodes tagged with 'gke-node'
  source_tags = ["gke-node"]
  target_tags = ["gke-node"]
}
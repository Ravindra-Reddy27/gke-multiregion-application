# terraform/modules/gke/main.tf

# 1. Dedicated Service Account for the GKE Nodes
resource "google_service_account" "node_sa" {
  account_id   = "gke-node-sa-${var.region}"
  display_name = "GKE Node Service Account for ${var.region}"
  project      = var.project_id
}

# 2. The GKE Cluster (Control Plane)
resource "google_container_cluster" "primary" {
  name     = "gke-cluster-${var.region}"
  # Providing a region instead of a zone makes this a regional cluster
  location = var.region
  project  = var.project_id

  network    = var.network_id
  subnetwork = var.subnet_id

  # Best Practice: Delete the default node pool and manage it separately
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable the node_location spin the vm in this zone only.
  node_locations = var.node_zones
  
  # Enable Workload Identity (Required for a later phase)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# 3. The Custom Node Pool (Worker Machines)
resource "google_container_node_pool" "primary_nodes" {
  name       = "main-node-pool-${var.region}"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  project    = var.project_id

  node_count = var.node_count
  
 #This forces GKE to skip the default zones and create nodes in this zones.
  node_locations = var.node_zones

  node_config {
    # e2-medium is a good cost-effective size for our sample app
    
    machine_type = "e2-medium"
    disk_type    = "pd-standard"
    
    

    #Attach our dedicated service account
    service_account = google_service_account.node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Tag the nodes so our VPC firewall rules apply to them
    tags = ["gke-node"]
  }
}
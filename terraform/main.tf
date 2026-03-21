# terraform/main.tf

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    # Add the helm provider requirement here
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12" 
    }
  }
  
  # Best Practice: Use a GCS bucket to store state files remotely
  backend "gcs" {
    bucket = "terraform-state-gpp" 
    prefix = "terraform/state"
  }
}

# FIX: Moved the Helm provider OUTSIDE the terraform block
provider "helm" {
  kubernetes {
    host                   = "https://${module.gke_primary.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke_primary.cluster_ca_certificate)
  }
}

provider "google" {
  project = var.project_id
}

resource "google_project_service" "required_services" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",  
    "iam.googleapis.com",
    "artifactregistry.googleapis.com"
  ])
  service = each.key
  disable_dependent_services = true
}

# 1. Create the Custom VPC and Subnets
module "vpc" {
  source           = "./modules/vpc"
  project_id       = var.project_id
  primary_region   = var.primary_region
  secondary_region = var.secondary_region
  
  depends_on = [
    google_project_service.required_services
  ]
}

# 2. Create the Primary GKE Cluster
module "gke_primary" {
  source     = "./modules/gke"
  project_id = var.project_id
  region     = var.primary_region
  node_count = 2
  network_id = module.vpc.network_id
  subnet_id  = module.vpc.primary_subnet_id
  node_zones = ["us-central1-b"]

  depends_on = [
    google_project_service.required_services
  ]
}

# 3. Create the Secondary GKE Cluster
module "gke_secondary" {
  source     = "./modules/gke"
  project_id = var.project_id
  region     = var.secondary_region
  node_count = 2
  network_id = module.vpc.network_id
  subnet_id  = module.vpc.secondary_subnet_id
  node_zones = ["us-east1-d"]

  depends_on = [
    google_project_service.required_services,
    module.gke_primary
  ]
}

resource "google_project_iam_member" "artifact_registry_reader_us_central1" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:gke-node-sa-us-central1@gke-multiregion-application.iam.gserviceaccount.com"
  depends_on = [
    google_project_service.required_services,
    module.gke_primary
  ]
}


resource "google_project_iam_member" "artifact_registry_reader_us_east1" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:gke-node-sa-us-east1@gke-multiregion-application.iam.gserviceaccount.com"
  depends_on = [
    google_project_service.required_services,
    module.gke_secondary
  ]
}

resource "google_artifact_registry_repository" "my_repo" {
  project       = var.project_id
  location      = var.primary_region
  repository_id = "my-repo"
  description   = "Docker repository for multi-tier app"
  format        = "DOCKER"
  depends_on = [
    google_project_service.required_services
  ]
}

# Add this data block to get your GCP authentication token
data "google_client_config" "default" {}

# Add this resource to install ArgoCD via Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.7" # Use a stable chart version

  # Ensure the cluster exists before trying to install ArgoCD
  depends_on = [module.gke_primary] 
}

# Install Prometheus and Grafana Stack
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "55.4.0" # Stable version

  # This value ensures Prometheus watches for our ServiceMonitor
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  depends_on = [module.gke_primary] 
}


# 1. Create the Google Service Account (GSA) for the application
resource "google_service_account" "app_gsa" {
  account_id   = "multi-tier-app-gsa"
  display_name = "GSA for Multi-Tier Application"
  project      = var.project_id
}

# 2. Bind the GSA to the Kubernetes Service Account (KSA)
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.app_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  
  # The strict Workload Identity member format: serviceAccount:PROJECT_ID.svc.id.goog[NAMESPACE/KSA_NAME]
  member = "serviceAccount:${var.project_id}.svc.id.goog[default/backend-ksa]"
}

# Create a GCS Bucket for Velero Backups
resource "google_storage_bucket" "velero_backups" {
  name          = "${var.project_id}-velero-backups-vault"
  location      = "US" # Multi-region for disaster recovery
  force_destroy = true

  uniform_bucket_level_access = true
}

# Install Velero via Helm
resource "helm_release" "velero" {
  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  namespace        = "velero"
  create_namespace = true

  # 1. Backup Storage Location (Where the files go)
  set {
    name  = "configuration.backupStorageLocation[0].provider"
    value = "gcp"
  }
  set {
    name  = "configuration.backupStorageLocation[0].name"
    value = "default"
  }
  set {
    name  = "configuration.backupStorageLocation[0].bucket"
    value = google_storage_bucket.velero_backups.name
  }

  # 2. Enable snapshotting for Persistent Volumes (Database)
  set {
    name  = "snapshotsEnabled"
    value = "true"
  }

  # 3. ADD THIS: Volume Snapshot Location (Who handles the physical disk)
  set {
    name  = "configuration.volumeSnapshotLocation[0].provider"
    value = "gcp"
  }
  set {
    name  = "configuration.volumeSnapshotLocation[0].name"
    value = "default"
  }

  depends_on = [module.gke_primary, google_storage_bucket.velero_backups]
}
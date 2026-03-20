# terraform/variables.tf

variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "primary_region" {
  description = "The primary region for the first GKE cluster"
  type        = string
  default     = "us-central1"
}

variable "secondary_region" {
  description = "The secondary region for the second GKE cluster"
  type        = string
  default     = "us-east1"
}
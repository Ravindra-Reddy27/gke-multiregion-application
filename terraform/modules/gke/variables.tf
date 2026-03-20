# terraform/modules/gke/variables.tf

variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "region" {
  description = "The region to deploy the GKE cluster in"
  type        = string
}

variable "network_id" {
  description = "The ID of the VPC network"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet for this region"
  type        = string
}

variable "node_zones" {
  type        = list(string)
  description = "A list of specific zones to deploy nodes into, bypassing stockouts."
}

variable "node_count" {
  type = number
  description = "Number of nodes"
}
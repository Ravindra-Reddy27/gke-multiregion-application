# terraform/modules/vpc/outputs.tf

output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.main.id
}

output "primary_subnet_id" {
  description = "The ID of the primary subnet"
  value       = google_compute_subnetwork.primary.id
}

output "secondary_subnet_id" {
  description = "The ID of the secondary subnet"
  value       = google_compute_subnetwork.secondary.id
}
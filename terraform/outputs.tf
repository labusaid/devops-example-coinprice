output "kubernetes_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE Cluster Name"
}

output "kubernetes_cluster_host" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE Cluster Host"
}

output "artifact_registry_repository" {
  value       = google_artifact_registry_repository.repo.name
  description = "Artifact Registry Repository"
}
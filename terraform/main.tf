# terraform/main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    bucket = "terraform-state-crypto-price"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable required APIs
resource "google_project_service" "services" {
  for_each = toset([
    "container.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com"
  ])

  service = each.key
  disable_on_destroy = false
}

# Create Artifact Registry Repository
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "crypto-price-repo"
  description   = "Docker repository for crypto price server"
  format        = "DOCKER"

  depends_on = [google_project_service.services]
}

# Create GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  depends_on = [google_project_service.services]
}

# Create Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name

  node_count = 2

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    machine_type = "e2-medium"
    disk_size_gb = 50
    disk_type    = "pd-standard"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = {
      env = "production"
    }
  }

  autoscaling {
    min_node_count = 2
    max_node_count = 5
  }
}

# Create VPC
resource "google_compute_network" "vpc" {
  name                    = "crypto-price-vpc"
  auto_create_subnetworks = false
}

# Create Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "crypto-price-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.name
}
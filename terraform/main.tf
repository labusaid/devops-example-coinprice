# Terraform configuration
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    bucket = "terraform-state-coinprice"
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
  repository_id = "devops-example-coinprice"
  description   = "Docker repository for crypto price server"
  format        = "DOCKER"

  depends_on = [google_project_service.services]
}

# Create CI/CD pipeline
resource "google_cloudbuild_trigger" "coinprice_server_trigger" {
  name        = "coinprice-server-trigger"
  description = "Trigger for building and deploying coinprice server"
  location    = var.region

  github {
    owner = "labusaid"
    name  = var.repo_name
    push {
      branch = "^master$"  # branch trigger regex
    }
  }

  filename = "cloudbuild.yaml"
}

# Create GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone # set to zone instead of region for cost savings

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
  location   = var.zone
  cluster    = google_container_cluster.primary.name

  node_count = 2

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # cheap nodes for cost optimization (should stay within free tier if only one node is used)
    machine_type = "e2-micro"
    disk_size_gb = 10
    disk_type    = "pd-standard"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = {
      env = "production"
    }
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }
}

# Create VPC
resource "google_compute_network" "vpc" {
  name                    = "coinprice-vpc"
  auto_create_subnetworks = false
}

# Create Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "coinprice-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.name
}

# Create a billing budget
resource "google_billing_budget" "budget" {
  billing_account = var.billing_account_id
  display_name    = "Monthly Billing Alert"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units        = "25" # Set your threshold amount
    }
  }

  threshold_rules {
    threshold_percent = 0.5  # Alert at 50% of budget
    spend_basis      = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.8  # Alert at 80% of budget
    spend_basis      = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0  # Alert at 100% of budget
    spend_basis      = "CURRENT_SPEND"
  }

  # Email alerts to specified recipients
  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.email.name
    ]
  }
}

# Create a notification channel for email alerts
resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Billing Alert Email"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}
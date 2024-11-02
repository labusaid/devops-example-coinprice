# Terraform configuration
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
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
  user_project_override = true
  billing_project = var.project_id
}

# Get Google client configuration
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Bootstrap managing services
resource "google_project_service" "cloudresourcemanager" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_on_destroy = false
}

# Enable other services
resource "google_project_service" "services" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "clouddeploy.googleapis.com",
  ])

  project = var.project_id
  service = each.key
  disable_on_destroy = false

  depends_on = [google_project_service.cloudresourcemanager]
}

# Create Artifact Registry Repository
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "devops-example-coinprice"
  description   = "Docker repository for crypto price server"
  format        = "DOCKER"

  depends_on = [google_project_service.services]
}

// Create a secret containing the personal access token and grant permissions to the Service Agent
resource "google_secret_manager_secret" "github_token_secret" {
    project =  var.project_id
    secret_id = var.secret_id

    replication {
        auto {}
    }
}

resource "google_secret_manager_secret_version" "github_token_secret_version" {
    secret = google_secret_manager_secret.github_token_secret.id
    secret_data = var.github_pat
}

data "google_iam_policy" "serviceagent_secretAccessor" {
    binding {
        role = "roles/secretmanager.secretAccessor"
        members = ["serviceAccount:service-${var.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
    }
}

resource "google_secret_manager_secret_iam_policy" "policy" {
  project = google_secret_manager_secret.github_token_secret.project
  secret_id = google_secret_manager_secret.github_token_secret.secret_id
  policy_data = data.google_iam_policy.serviceagent_secretAccessor.policy_data
}

// Create the GitHub connection
resource "google_cloudbuildv2_connection" "coinprice_github_connection" {
    project = var.project_id
    location = var.region
    name = "coinprice-github-connection"

    github_config {
        app_installation_id = var.installation_id
        authorizer_credential {
            oauth_token_secret_version = google_secret_manager_secret_version.github_token_secret_version.id
        }
    }
    depends_on = [google_secret_manager_secret_iam_policy.policy]
}

# Create CloudBuild connection
resource "google_cloudbuildv2_repository" "coinprice_cloudbuild_repository" {
  project          = var.project_id
  location         = var.region
  name             = var.repo_name
  parent_connection = google_cloudbuildv2_connection.coinprice_github_connection.name
  remote_uri       = var.repo_uri
}

# Create the service account for Cloud Build
resource "google_service_account" "cloudbuild_service_account" {
  project      = var.project_id
  account_id   = "cloudbuild-trigger-sa"
  display_name = "Cloud Build Trigger Service Account"
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "cloudbuild_roles" {
  for_each = toset([
    "roles/cloudbuild.builds.builder",
    "roles/viewer"
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}

# Grant additional permissions for Kubernetes deployments
resource "google_project_iam_member" "cloudbuild_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}

# Create build trigger
resource "google_cloudbuild_trigger" "filename-trigger" {
  project = var.project_id
  name    = "master-branch-trigger"
  location = var.region

  service_account = google_service_account.cloudbuild_service_account.id

  github {
    owner = split("/", var.repo_uri)[3]
    name  = var.repo_name
    push {
      branch = "^master$"
    }
  }

  filename = "cloudbuild.yaml"

  depends_on = [
    google_cloudbuildv2_repository.coinprice_cloudbuild_repository,
    google_project_iam_member.cloudbuild_roles,
    google_project_iam_member.cloudbuild_developer
  ]
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

  node_count = 1

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # cheap nodes for cost optimization
    machine_type = "e2-small"
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
    max_node_count = 10
  }
}

# Apply Kubernetes manifest
# Read and split file by '---'
locals {
  manifests = split("---", file("../kubernetes/k8smanifests.yaml"))
}

# Apply each manifest as a separate Kubernetes resource
resource "kubernetes_manifest" "multi_manifests" {
  count    = length(local.manifests)
  manifest = yamldecode(local.manifests[count.index])

  field_manager {
    force_conflicts = true
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
    projects = ["projects/${var.project_number}"]
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
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "repo_name" {
  description = "Github Repo Name"
  type        = string
  default     = "devops-example-coinprice"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "coinprice-cluster"
}

variable "billing_account_id" {
  description = "The ID of the billing account"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive billing alerts"
  type        = string
}
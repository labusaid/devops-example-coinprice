variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_number" {
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

variable "repo_uri" {
  description = "uri of github repo .git"
  type        = string
  default = "https://github.com/labusaid/devops-example-coinprice.git"
}

variable "secret_id" {
  description = "id for github pat secret in secret manager"
  type        = string
  default = "github_pat"
}

variable "github_pat" {
  description = "github personal access token ID"
  type        = string
}

variable "installation_id" {
  description = "id of github connection at https://github.com/settings/installations/"
  type        = string
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
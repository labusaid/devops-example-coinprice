# Initialize GCP project
gcloud init

# Create a GCS bucket for Terraform state
gsutil mb gs://terraform-state-coinprice

# Enable required APIs
gcloud services enable container.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com

# Initialize Terraform
cd terraform || exit
terraform init

# Set project ID
export TF_VAR_project_id="devops-example-coinprice"

# Plan and apply Terraform
terraform plan
terraform apply

# Give Cloud Build permission to deploy to GKE
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com" \
    --role="roles/container.developer"
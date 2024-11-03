# Coinprice Devops Example
This project is intended to serve as a demo of using Terraform, Docker, Kubernetes, and Google Cloud Platform to build a basic DevOps environment for a Flask API.  This readme is intended to be a guide for those who would like to deploy this environment, for a general overview there is an accompanying writeup on my website:   
https://latheabusaid.com/coinprice

## Prerequisites
In order to deploy this app, you need to have a couple of command line tools installed on your machine.
I recommend using [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) if you are on Windows, I haven't tested it but powershell should work as well if that's preferred. 

#### gcloud CLI
The gcloud CLI tool is used to configure Google Cloud Platform (GCP) resources from the command line.
Some basic setup steps will need to be done with this one time before Terraform can take over.

gcloud CLI install instructions can be found here:  
https://cloud.google.com/sdk/docs/install

#### Terraform
Terraform is used to define Infrastructure as Code (IaC), this will automate 90% of the deployment steps once set up.

Terraform can be downloaded for your platform here:  
https://developer.hashicorp.com/terraform/install

## GitHub Configuration
In order for CI/CD to work properly you will need to set up a few things in your GitHub account.

First, install the Google Cloud Build GitHub app: https://github.com/marketplace/google-cloud-build

Then you will need to create a GitHub Personal Access Token from here:
https://github.com/settings/tokens

Make sure to select "classic" from the dropdown. Set the expiration to "no expiration" and then give the token the following permissions:
```
repo
workflow
read:org
read:user
```

## Google Cloud Setup
If you have not set up you `gcloud` cli yet now is the time to do so.
This can be done by running:
```shell
gcloud init
```

You also need to create a Google cloud project if you don't already have one.
I recommend doing this manually from the [Google cloud console](https://console.cloud.google.com/), since billing will need to be enabled for this project.
Most things have been cost optimized and should stay under a couple dollars per month, but alerts are set up for a budget of $25 at 50,80,and 100% of the budget.

Now you can configure your gcloud cli to use the project. Replace `PROJECT_ID` with the project id you set for the new project.
```shell
gcloud config set project PROJECT_ID
```

Terraform requires a place to store the state of the current infrastructure, you can create a gcs bucket for this with:
```shell
# Create a GCS bucket for Terraform state
gsutil mb gs://terraform-state-coinprice
```

## Terraform Configuration
Most Terraform variables are set to defaults which should work for most people, but some need to be specific to your project.
To define these variables, create a file in the `/terraform` directory called `terraform.tfvars` and paste the following into it. Replace the values with the ones for your project.
```terraform
project_id = "YOUR_PROJECT_ID"
project_number = "YOUR_PROJECT_NUMBER"
billing_account_id = "XXXXXX-XXXXXX-XXXXXX"
alert_email = "alerts@yourdomain.com"
installation_id = "GITHUB_INSTALLATION_ID"
github_pat = "YOUR_GITHUB_ACCESS_TOKEN"
```
- **`project_id`**: The unique identifier of your Google Cloud project. This is a string value representing the Google Cloud Project ID where resources will be created or managed. You can find this in the Google Cloud Console under your project's details.

- **`project_number`**: The unique numeric identifier for your Google Cloud project. You can find the project number in the Google Cloud Console.

- **`billing_account_id`**: The identifier of the Google Cloud billing account to associate with the project. This can be found in the Google Cloud Console.

- **`alert_email`**: The email address where alerts and notifications will be sent.

- **`installation_id`**: The unique identifier for the GitHub App installation. This can be found in the url when you click "configure" on the Google Cloud Build Integration here: https://github.com/settings/installations 

- **`github_pat`**: The GitHub Personal Access Token (PAT) you set up earlier.

## Terraform Deployment
To deploy the application infrastructure with Terraform, run the following commands:
```shell
cd terraform
terraform init
terraform plan
terraform apply
```
Now you get to sit back and watch the fireworks! I can't guarantee this will work on the first try, but I was able to successfully run a `terraform destroy` and redeploy everything without any issues.
# Multi-Region GKE Multi-Tier Application with GitOps

##  Project Overview

This repository contains a production-grade, highly available, multi-tier web application deployed across multiple Google Cloud (GCP) regions. It utilizes modern Cloud Native and DevOps best practices, including Infrastructure as Code (IaC), GitOps, automated CI/CD pipelines, robust observability, and disaster recovery.


### Architecture Highlights

- **Infrastructure:** Multi-region Google Kubernetes Engine (GKE) clusters provisioned via Terraform.
- **Containerization:** A Python/Flask backend and an Nginx/HTML frontend, fully containerized with Docker.
- **Orchestration:** Managed via Kubernetes Helm Charts with StatefulSets for the PostgreSQL database.
- **CI/CD:** Automated builds and container registry pushes using GitHub Actions.
- **GitOps:** Continuous deployment and cluster synchronization managed by ArgoCD.
- **Security:** GKE Workload Identity and strict Kubernetes Network Policies (Default Deny).
- **Observability:** Prometheus metrics scraping and custom Grafana dashboards.
- **Disaster Recovery:** Automated volume snapshots and cross-region backups using Velero.

---

## 📂 Repository Structure

```text
.
├── app/                        # Application source code
│   ├── backend/                # Python Flask API & Dockerfile
│   ├── frontend/               # Nginx static site & Dockerfile
├── argocd/                     # GitOps Application manifests
├── charts/                     # Helm chart for Kubernetes deployment
│   └── my-app/                 # Templates, Network Policies, Velero schedules
├── terraform/                  # Infrastructure as Code (GCP & GKE)
├── .github/workflows/          # CI/CD Pipeline (GitHub Actions)
├── docker-compose.yml          # Local development environment
├── .env.example                # Example environment variables
├── FAILOVER.md                 # Disaster Recovery & Failover documentation
├── grafana-dashboard.json      # Custom monitoring dashboard
├── submission.json             # Automated grading metadata
└── README.md                   # Project documentation
```

---

##  Prerequisites

To deploy this infrastructure from scratch, you will need the following tools installed on your local machine:

- **Google Cloud SDK** (`gcloud`) — Authenticated to your GCP project.
- **gke-gcloud-auth-plugin** — Authentication with GKE clusters.
- **Terraform** (>= 1.0.0)
- **Docker & Docker Compose**
- **Kubernetes CLI** (`kubectl`)
- **Helm**
- A **GitHub account** and a **Personal Access Token** (for ArgoCD/Actions integration).

---

##  Local Development Setup (Docker Compose)

Before deploying to the cloud, you can run the application locally to verify the code works.

**1. Clone the repository:**

```bash
git clone https://github.com/Ravindra-Reddy27/gke-multiregion-application.git
cd gke-multiregion-application
```

**3. Start the application:**

```bash
docker compose up --build -d
```

**4. Verify local access:**

- Frontend: [http://localhost:8081](http://localhost:8081)
- Backend Health: [http://localhost:5000/](http://localhost:5000/)

**5. Shut down local environment:**

```bash
docker compose down
```

---

##  Cloud Deployment Guide

### Step 0:  Terraform Remote State Setup (GCS)

 Create a Cloud Storage Bucket (with location)

```bash

gcloud storage buckets create gs://terraform-state-gpp `
  --location=us-central1 
```

Enable Versioning (for state safety)

```bash

gcloud storage buckets update gs://terraform-state-gpp `
  --versioning
```


### Step 1: Configuration Setup
A. Create terraform.tfvars File
Before running Terraform, create your variables file from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

> 👉 Then open `terraform.tfvars` and update the values as needed.

> 👉 If `terraform.tfvars` already it in the repo, update the project id value with your project id..

B. Update Project ID in Helm Values

Navigate to the Helm configuration file:

`helm/values.yaml`

👉 Find the projectId and replace it with your GCP project ID.



### Step 2: Provision Infrastructure (Terraform)

This step provisions the VPCs, Subnets, Artifact Registry, GKE Clusters, Workload Identity, ArgoCD, and Velero.

**Navigate to the terraform directory:**

```bash
cd terraform
```

**Initialize Terraform and download providers:**

```bash
terraform init
```

**Review the execution plan:**

```bash
terraform plan
```

**Apply the infrastructure configuration** *(This takes ~15–20 minutes)*:

```bash
terraform apply
```

---

### Step 2: Configure CI/CD (GitHub Actions)

The deployment relies on GitHub Actions to build Docker images and push them to Google Artifact Registry.

1. Go to your **GitHub Repository → Settings → Secrets and variables → Actions**.
2. Add the following **Repository Secrets**:
   - `GCP_PROJECT_ID` — Your Google Cloud Project ID.
   - `GCP_CREDENTIALS` — The JSON key for a Service Account with Artifact Registry Writer permissions.

    >1. Go to your Google Cloud Console, navigate to IAM & Admin > Service Accounts.
    >2. Create a new Service Account (e.g., github-actions-sa).
    >3. Grant it the Artifact Registry Writer role (so it can push images).
    >4. Go to the "Keys" tab for that service account, click Add Key > Create New Key > JSON, and download the file.
    >5. Update the key values and some data in secrets in github actions.

3. Ensure GitHub Actions has **Read/Write permissions** *(Settings → Actions → General → Workflow Permissions)*.

> Any push to the `main` branch will now automatically trigger the pipeline, build the images, and update the Helm `values.yaml` file with the new image tags.

4. Push the terraform.tfvars file to your github repo it used by main.tf.

---

### Step 3: Deploy the Application (ArgoCD GitOps)

Because ArgoCD was installed via Terraform, it is already running in your cluster. We just need to apply the GitOps manifest.

**Authenticate to your primary GKE cluster:**

```bash
gcloud container clusters get-credentials gke-cluster-us-central1 --region us-central1
```

**Apply the ArgoCD application manifest:**

```bash
kubectl apply -f argocd/application.yaml
```

> ArgoCD will now automatically detect your Helm chart in GitHub and deploy your Frontend, Backend, Database (StatefulSet), Network Policies, and Velero schedules!

---

##  Accessing the Application

Once ArgoCD reports the application is **Synced** and **Healthy**, you can access the live environment.

**Retrieve the public IP address of the Ingress Load Balancer:**

```bash
kubectl get ingress
```
Open the IP address in the browser.

---

##  Monitoring & Observability

Prometheus and Grafana are installed automatically via Terraform.

**Port-forward the Grafana service to access the UI locally:**

```bash
kubectl port-forward svc/prometheus-grafana 8080:80 -n monitoring
```

Open [http://localhost:8080](http://localhost:8080) in your browser.

Username: `admin`

Password: By default, the Helm chart sets the password to `prom-operator`.

Import the `grafana-dashboard.json` file located in the root of this repository to view live backend HTTP traffic and CPU usage metrics.

---

##  Cleanup / Teardown

To avoid incurring unnecessary cloud costs, destroy the infrastructure when you are finished.

**Navigate back to the Terraform directory:**

```bash
cd terraform
```

**Destroy all provisioned resources:**

```bash
terraform destroy
```

> **Note:** You may need to manually empty the Google Cloud Storage Velero backup bucket before Terraform can successfully delete it.
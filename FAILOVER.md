# Disaster Recovery Plan: Multi-Region Failover

## Objective
The objective of this plan is to outline the exact steps required to restore the multi-tier application in the event of a total regional outage in the primary Google Cloud region (`us-central1`).
* **Recovery Point Objective (RPO):** 24 Hours (Based on the `daily-app-backup` Velero schedule).
* **Recovery Time Objective (RTO):** 2 Hours (Time to provision secondary cluster via Terraform and restore state).

## Prerequisites
To execute this failover plan, the responding engineer must have:
* Google Cloud SDK (`gcloud`) installed and authenticated with Project Owner or Kubernetes Engine Admin permissions.
* The Kubernetes CLI (`kubectl`) installed.
* The Velero CLI (`velero`) installed.

## Failover Steps
Follow these steps in sequence to initiate the disaster recovery process:

1. **Declare a Disaster and Initiate Failover**
   * Confirm the primary region (`us-central1`) is unresponsive and declare a formal severity incident.
   * Halt any running GitHub Actions CI/CD pipelines to prevent split-brain deployments.

2. **Configure the Secondary Cluster as the Recovery Target**
   * Authenticate your local terminal to the secondary cluster deployed in `us-east1`:
     ```bash
     gcloud container clusters get-credentials gke-cluster-us-east1 --region us-east1
     ```
   * Ensure the Velero namespace and Helm deployment exist on the secondary cluster (managed via Terraform).

3. **Use Velero to Restore the Latest Backup to the Secondary Cluster**
   * Verify the secondary cluster can see the Google Cloud Storage backup vault:
     ```bash
     velero backup get
     ```
   * Identify the most recent successful backup from the `daily-app-backup` schedule.
   * Initiate the restore process (including Persistent Volumes for the database):
     ```bash
     velero restore create --from-backup <LATEST_BACKUP_NAME> --restore-volumes=true
     ```

4. **Update DNS or Load Balancer Configurations to Route Traffic**
   * Retrieve the new public IP address of the Nginx Ingress Controller on the secondary cluster:
     ```bash
     kubectl get ingress -n default
     ```
   * Open the IP address in browser.

## Verification Steps
Once the DNS has propagated, perform the following checks to confirm the application is running correctly in the secondary region:
- [ ] `kubectl get pods` shows both `frontend` and `backend` pods in a `Running` state.
- [ ] `kubectl get statefulset` shows the `database` is fully provisioned and bound to its restored Persistent Volume.
- [ ] The backend API successfully reads and writes data to the restored PostgreSQL database.
The Final Push
#!/bin/bash
# ==========================================
# Money Tracker App Deployment Automation
# ==========================================

# 1. Variabel
PROJECT_ID="submission-mgce-rnlkav"
REGION="asia-southeast2"
ZONE="asia-southeast2-a"
BUCKET_NAME="bucket-money-tracker-${PROJECT_ID}"
DB_PASSWORD="r00t133#"

echo "=== Mengatur Project Aktif ==="
gcloud config set project $PROJECT_ID

echo "=== Menyiapkan Cloud Storage ==="
gsutil mb -l $REGION gs://$BUCKET_NAME
gsutil iam ch allUsers:objectViewer gs://$BUCKET_NAME
# Set Lifecycle Management
cat <<EOF > lifecycle.json
{
  "rule": [{"action": {"type": "Delete"}, "condition": {"age": 30}}]
}
EOF
gsutil lifecycle set lifecycle.json gs://$BUCKET_NAME

echo "=== Menyiapkan Service Account & IAM ==="
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:reviewer_googlecloud@dicoding.com" \
    --role="roles/viewer"

gcloud iam service-accounts create money-tracker-sa --display-name="Money Tracker Service Account"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:money-tracker-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"

gcloud iam service-accounts keys create ./money-tracker-api-gcp/serviceaccountkey.json \
    --iam-account=money-tracker-sa@${PROJECT_ID}.iam.gserviceaccount.com

gcloud projects add-iam-policy-binding $PROJECT_ID \
--member="serviceAccount:${PROJECT_ID}@appspot.gserviceaccount.com" \
--role="roles/editor"


echo "=== Menyiapkan Cloud SQL ==="
gcloud sql instances create money-tracker-db \
    --database-version=MYSQL_5_7 \
    --cpu=1 --memory=3840MB \
    --region=$REGION \
    --root-password=$DB_PASSWORD

gcloud sql databases create money_tracker_db --instance=money-tracker-db

echo "=== Menyiapkan VM Compute Engine Backend ==="
gcloud compute firewall-rules create allow-backend-8000 \
    --allow=tcp:8000 \
    --target-tags=http-server
gcloud compute firewall-rules create allow-backend-8080 \
    --allow=tcp:8080 \
    --target-tags=http-server

gcloud compute instances create money-tracker-backend-vm \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --tags=http-server \
    --scopes=cloud-platform

echo "=== Setup Selesai! Lakukan import SQL dan deploy VM & App Engine ==="
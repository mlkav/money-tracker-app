#!/bin/bash
# ==========================================
# Money Tracker App - Cleanup / Teardown
# ==========================================
#
# Prinsip:
# - Jika satu resource gagal dihapus, proses tetap lanjut.
# - Resource yang sudah tidak ada akan di-skip.
# - Di akhir akan ditampilkan ringkasan SUCCESS / FAILED.
# ==========================================

PROJECT_ID="submission-mgce-rnlkav"
REGION="asia-southeast2"
ZONE="asia-southeast2-a"

BUCKET_NAME="bucket-money-tracker-${PROJECT_ID}"

SERVICE_ACCOUNT_NAME="money-tracker-sa"
SERVICE_ACCOUNT="money-tracker-sa@${PROJECT_ID}.iam.gserviceaccount.com"
APP_ENGINE_SA="${PROJECT_ID}@appspot.gserviceaccount.com"

VM_NAME="money-tracker-backend-vm"

SQL_INSTANCE="money-tracker-db"
SQL_DATABASE="money_tracker_db"

FIREWALL_8000="allow-backend-8000"
FIREWALL_8080="allow-backend-8080"

LOCAL_KEY_FILE="./money-tracker-api-gcp/serviceaccountkey.json"
LOCAL_LIFECYCLE_FILE="./lifecycle.json"

# ==========================================
# Status Tracking
# ==========================================

SUCCESS=()
FAILED=()
SKIPPED=()

success() {
    SUCCESS+=("$1")
    echo "  ✓ $1"
}

failed() {
    FAILED+=("$1")
    echo "  ✗ $1"
}

skipped() {
    SKIPPED+=("$1")
    echo "  - $1"
}

# ==========================================
# Header
# ==========================================

echo ""
echo "=========================================="
echo " Money Tracker App - CLEANUP"
echo "=========================================="
echo ""
echo "Project : $PROJECT_ID"
echo "Region  : $REGION"
echo "Zone    : $ZONE"
echo ""

# ==========================================
# Set Active Project
# ==========================================

echo "=== Mengatur Project Aktif ==="

if gcloud config set project "$PROJECT_ID"; then
    success "Set project: $PROJECT_ID"
else
    failed "Set project: $PROJECT_ID"
fi

# ==========================================
# 1. Delete Compute Engine VM
# ==========================================

echo ""
echo "=== 1. Menghapus Compute Engine VM ==="

if gcloud compute instances describe "$VM_NAME" \
    --zone="$ZONE" >/dev/null 2>&1; then

    echo "Menghapus VM: $VM_NAME"

    if gcloud compute instances delete "$VM_NAME" \
        --zone="$ZONE" \
        --quiet; then

        success "Compute Engine VM: $VM_NAME"
    else
        failed "Compute Engine VM: $VM_NAME"
    fi

else
    skipped "Compute Engine VM: $VM_NAME (tidak ditemukan)"
fi

# ==========================================
# 2. Delete Firewall Rule 8000
# ==========================================

echo ""
echo "=== 2. Menghapus Firewall Rule 8000 ==="

if gcloud compute firewall-rules describe "$FIREWALL_8000" \
    >/dev/null 2>&1; then

    echo "Menghapus firewall: $FIREWALL_8000"

    if gcloud compute firewall-rules delete "$FIREWALL_8000" \
        --quiet; then

        success "Firewall: $FIREWALL_8000"
    else
        failed "Firewall: $FIREWALL_8000"
    fi

else
    skipped "Firewall: $FIREWALL_8000 (tidak ditemukan)"
fi

# ==========================================
# 3. Delete Firewall Rule 8080
# ==========================================

echo ""
echo "=== 3. Menghapus Firewall Rule 8080 ==="

if gcloud compute firewall-rules describe "$FIREWALL_8080" \
    >/dev/null 2>&1; then

    echo "Menghapus firewall: $FIREWALL_8080"

    if gcloud compute firewall-rules delete "$FIREWALL_8080" \
        --quiet; then

        success "Firewall: $FIREWALL_8080"
    else
        failed "Firewall: $FIREWALL_8080"
    fi

else
    skipped "Firewall: $FIREWALL_8080 (tidak ditemukan)"
fi

# ==========================================
# 4. Delete Cloud SQL Database
# ==========================================

echo ""
echo "=== 4. Menghapus Cloud SQL Database ==="

if gcloud sql databases describe "$SQL_DATABASE" \
    --instance="$SQL_INSTANCE" >/dev/null 2>&1; then

    echo "Menghapus database: $SQL_DATABASE"

    if gcloud sql databases delete "$SQL_DATABASE" \
        --instance="$SQL_INSTANCE" \
        --quiet; then

        success "Cloud SQL Database: $SQL_DATABASE"
    else
        failed "Cloud SQL Database: $SQL_DATABASE"
    fi

else
    skipped "Cloud SQL Database: $SQL_DATABASE (tidak ditemukan)"
fi

# ==========================================
# 5. Delete Cloud SQL Instance
# ==========================================

echo ""
echo "=== 5. Menghapus Cloud SQL Instance ==="

if gcloud sql instances describe "$SQL_INSTANCE" \
    >/dev/null 2>&1; then

    echo "Menghapus Cloud SQL instance: $SQL_INSTANCE"

    if gcloud sql instances delete "$SQL_INSTANCE" \
        --quiet; then

        success "Cloud SQL Instance: $SQL_INSTANCE"
    else
        failed "Cloud SQL Instance: $SQL_INSTANCE"
    fi

else
    skipped "Cloud SQL Instance: $SQL_INSTANCE (tidak ditemukan)"
fi

# ==========================================
# 6. Delete Cloud Storage Bucket
# ==========================================

echo ""
echo "=== 6. Menghapus Cloud Storage Bucket ==="

if gsutil ls -b "gs://$BUCKET_NAME" >/dev/null 2>&1; then

    echo "Menghapus seluruh object di bucket..."
    echo "Bucket: gs://$BUCKET_NAME"

    if gsutil -m rm -r "gs://$BUCKET_NAME"; then
        success "Cloud Storage Bucket: $BUCKET_NAME"
    else
        failed "Cloud Storage Bucket: $BUCKET_NAME"
    fi

else
    skipped "Cloud Storage Bucket: $BUCKET_NAME (tidak ditemukan)"
fi

# ==========================================
# 7. Remove Reviewer IAM Binding
# ==========================================

echo ""
echo "=== 7. Menghapus IAM Binding Reviewer ==="

if gcloud projects get-iam-policy "$PROJECT_ID" \
    --flatten="bindings[].members" \
    --filter="bindings.members:user:reviewer_googlecloud@dicoding.com AND bindings.role:roles/viewer" \
    --format="value(bindings.role)" \
    | grep -q "roles/viewer"; then

    if gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
        --member="user:reviewer_googlecloud@dicoding.com" \
        --role="roles/viewer" \
        --quiet; then

        success "IAM Reviewer: reviewer_googlecloud@dicoding.com"
    else
        failed "IAM Reviewer: reviewer_googlecloud@dicoding.com"
    fi

else
    skipped "IAM Reviewer binding (tidak ditemukan)"
fi

# ==========================================
# 8. Remove Service Account IAM Binding
# ==========================================

echo ""
echo "=== 8. Menghapus IAM Binding Service Account ==="

if gcloud projects get-iam-policy "$PROJECT_ID" \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:$SERVICE_ACCOUNT AND bindings.role:roles/storage.objectAdmin" \
    --format="value(bindings.role)" \
    | grep -q "roles/storage.objectAdmin"; then

    if gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SERVICE_ACCOUNT" \
        --role="roles/storage.objectAdmin" \
        --quiet; then

        success "IAM Service Account: roles/storage.objectAdmin"
    else
        failed "IAM Service Account: roles/storage.objectAdmin"
    fi

else
    skipped "IAM Service Account binding (tidak ditemukan)"
fi

# ==========================================
# 9. Remove App Engine IAM Binding
# ==========================================

echo ""
echo "=== 9. Menghapus IAM Binding App Engine ==="

if gcloud projects get-iam-policy "$PROJECT_ID" \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:$APP_ENGINE_SA AND bindings.role:roles/editor" \
    --format="value(bindings.role)" \
    | grep -q "roles/editor"; then

    if gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$APP_ENGINE_SA" \
        --role="roles/editor" \
        --quiet; then

        success "IAM App Engine: roles/editor"
    else
        failed "IAM App Engine: roles/editor"
    fi

else
    skipped "IAM App Engine binding (tidak ditemukan)"
fi

# ==========================================
# 10. Delete Service Account
# ==========================================

echo ""
echo "=== 10. Menghapus Service Account ==="

if gcloud iam service-accounts describe "$SERVICE_ACCOUNT" \
    >/dev/null 2>&1; then

    echo "Menghapus service account:"
    echo "$SERVICE_ACCOUNT"

    if gcloud iam service-accounts delete "$SERVICE_ACCOUNT" \
        --quiet; then

        success "Service Account: $SERVICE_ACCOUNT"
    else
        failed "Service Account: $SERVICE_ACCOUNT"
    fi

else
    skipped "Service Account: $SERVICE_ACCOUNT (tidak ditemukan)"
fi

# ==========================================
# 11. Delete Local Service Account Key
# ==========================================

echo ""
echo "=== 11. Menghapus File Credential Lokal ==="

if [ -f "$LOCAL_KEY_FILE" ]; then

    if rm -f "$LOCAL_KEY_FILE"; then
        success "Local file: $LOCAL_KEY_FILE"
    else
        failed "Local file: $LOCAL_KEY_FILE"
    fi

else
    skipped "Local file: $LOCAL_KEY_FILE (tidak ditemukan)"
fi

# ==========================================
# 12. Delete Local Lifecycle File
# ==========================================

echo ""
echo "=== 12. Menghapus lifecycle.json ==="

if [ -f "$LOCAL_LIFECYCLE_FILE" ]; then

    if rm -f "$LOCAL_LIFECYCLE_FILE"; then
        success "Local file: $LOCAL_LIFECYCLE_FILE"
    else
        failed "Local file: $LOCAL_LIFECYCLE_FILE"
    fi

else
    skipped "Local file: $LOCAL_LIFECYCLE_FILE (tidak ditemukan)"
fi

# ==========================================
# Summary
# ==========================================

echo ""
echo "=========================================="
echo " CLEANUP SUMMARY"
echo "=========================================="

echo ""
echo "SUCCESS:"
if [ ${#SUCCESS[@]} -eq 0 ]; then
    echo "  Tidak ada."
else
    for item in "${SUCCESS[@]}"; do
        echo "  ✓ $item"
    done
fi

echo ""
echo "FAILED:"
if [ ${#FAILED[@]} -eq 0 ]; then
    echo "  Tidak ada."
else
    for item in "${FAILED[@]}"; do
        echo "  ✗ $item"
    done
fi

echo ""
echo "SKIPPED:"
if [ ${#SKIPPED[@]} -eq 0 ]; then
    echo "  Tidak ada."
else
    for item in "${SKIPPED[@]}"; do
        echo "  - $item"
    done
fi

echo ""
echo "=========================================="

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "⚠️  Cleanup selesai, tetapi ada resource yang gagal dihapus."
    echo "    Silakan jalankan script kembali setelah memperbaiki masalah."
    echo "=========================================="
    exit 1
else
    echo "✓ Semua resource berhasil diproses."
    echo "=========================================="
    exit 0
fi

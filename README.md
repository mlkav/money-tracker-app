# Create in GCP

Langkah 1: Persiapan Project & Otorisasi IAM (Kriteria 1 & 2)
Buat Project Baru:

Buat Google Cloud Project dengan nama submission-mgce-[nama-peserta] (contoh: submission-mgce-budi).

Set Project Aktif di Cloud Shell:

```bash
gcloud config set project [PROJECT_ID_ANDA]
```

Beri Hak Akses ke Reviewer (Least Privilege):

```bash
gcloud projects add-iam-policy-binding [PROJECT_ID_ANDA] \
    --member="user:reviewer_googlecloud@dicoding.com" \
    --role="roles/viewer"
```

Langkah 2: Cloud Storage Setup & Lifecycle Management
Buat Bucket di Region asia-southeast2 (Jakarta):

```bash
gsutil mb -l asia-southeast2 gs://[NAMA_BUCKET_ANDA]
```
Atur Akses Publik pada Bucket:

```bash
gsutil iam ch allUsers:objectViewer gs://[NAMA_BUCKET_ANDA]
```

Terapkan Lifecycle Management (Persyaratan Poin Plus):
Buat berkas lifecycle.json:
```
JSON
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 30}
    }
  ]
}
```

Terapkan aturan ke bucket:

```bash
gsutil lifecycle set lifecycle.json gs://[NAMA_BUCKET_ANDA]
```

Langkah 3: Service Account & Credentials Backend
Buat Service Account Khusus:

```bash
gcloud iam service-accounts create money-tracker-sa \
    --display-name="Money Tracker Service Account"
```

Berikan Access Role (Least Privilege):

```bash
gcloud projects add-iam-policy-binding [PROJECT_ID_ANDA] \
    --member="serviceAccount:money-tracker-sa@[PROJECT_ID_ANDA].iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"
```

Generate Key JSON:

Clone repository API terlebih dahulu:

```bash
git clone -b money-tracker-api https://github.com/dicodingacademy/a133-gcp-labs.git money-tracker-api
```

Buat dan simpan key ke money-tracker-api/serviceaccountkey.json:

```bash
gcloud iam service-accounts keys create money-tracker-api/serviceaccountkey.json \
    --iam-account=money-tracker-sa@[PROJECT_ID_ANDA].iam.gserviceaccount.com
```
Langkah 4: Cloud SQL Setup & Database Schema
Buat Instance Cloud SQL (MySQL 5.7) di asia-southeast2:

```bash
gcloud sql instances create money-tracker-db \
    --database-version=MYSQL_5_7 \
    --cpu=1 --memory=3840MB \
    --region=asia-southeast2 \
    --root-password=[PASSWORD_DATABASE]
```

Buat Database:

```bash
gcloud sql databases create money_tracker_db \
    --instance=money-tracker-db
```

Import Skema Database:

```bash
gcloud sql connect money-tracker-db --user=root < money-tracker-api/create_table.sql
```
Langkah 5: Deploy Back-End ke Compute Engine (VM Instance)
Konfigurasi Berkas Backend di Cloud Shell Sebelum Diunggah:

- Edit money-tracker-api/modules/imgUpload.js: Isikan Project ID dan nama bucket Cloud Storage Anda.

Edit money-tracker-api/routes/record.js: Perbarui konfigurasi koneksi MySQL (host, user, password, database) sesuai kredensial Cloud SQL Instance Anda.

Buat Instance Compute Engine:
-
```bash
gcloud compute instances create money-tracker-backend-vm \
    --zone=asia-southeast2-a \
    --machine-type=e2-micro \
    --tags=http-server,https-server \
    --scopes=cloud-platform
```

Transfer File Kode Backend ke Compute Engine:

```bash
gcloud compute scp --recurse money-tracker-api money-tracker-backend-vm:~/ --zone=asia-southeast2-a
```

SSH ke Compute Engine:

```bash
gcloud compute ssh money-tracker-backend-vm --zone=asia-southeast2-a
Install Node.js & PM2 di dalam VM:

```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E ```bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2
```
Jalankan Backend Application:

```bash
cd ~/money-tracker-api
npm install
pm2 start app.js --name "backend-api"
exit
```
Catat External IP VM:
Dapatkan IP Publik VM Anda:

```bash
gcloud compute instances list
```
URL Backend Anda adalah http://[EXTERNAL_IP_VM]:8080 (atau port tempat Node.js berjalan, pastikan firewall port tersebut terbuka).

Langkah 6: Deploy Front-End ke App Engine
Clone Repository Frontend di Cloud Shell:

```bash
git clone -b money-tracker https://github.com/dicodingacademy/a133-gcp-labs.git money-tracker
cd money-tracker
```


Konfigurasi API Model:
Edit file application/models/Record_model.php:

Set 'base_uri' ke URL External IP Backend dari Langkah 5 tanpa / di akhir (contoh: "http://[EXTERNAL_IP_VM]:8080").

Buat Berkas app.yaml di Folder money-tracker:

```YAML
runtime: php83
service: default
```

Deploy Pertama Frontend ke App Engine:

```bash
gcloud app deploy
```

Catat URL Frontend dari terminal (misal: https://[PROJECT_ID].et.r.appspot.com).

Update Config Base URL Frontend:
Edit file application/config/config.php:

Uncomment dan ubah $config['base_url'] menjadi URL Frontend yang diperoleh.

Deploy Ulang Frontend:

```bash
gcloud app deploy
```

Langkah 7: Pengiriman Submission (project.json)
Buat berkas project.json berisi data infrastruktur:

```JSON
{
  "project_name": "submission-mgce-[nama-peserta]",
  "url_fe": "https://[PROJECT_ID].et.r.appspot.com",
  "url_be": "http://[EXTERNAL_IP_VM]:8080",
  "bucket_name": "[NAMA_BUCKET_ANDA]"
}
```

Unggah berkas project.json tersebut ke platform Dicoding.


DI VM BE
```
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v
npm -v
sudo npm install -g pm2
pm2 -v
ls -la
pm2 start app.js --name "backend-api"
sudo ss -ltnp | grep :8080
cat app.js
sudo ss -ltnp | grep :8000
curl -i http://localhost:8000
pm2 status
pm2 logs backend-api --lines 50
cat ~/serviceaccountkey.json
ls -la
cat ./serviceaccountkey.json
nano ~/money-tracker-api/routes/record.js
pm2 status
pm2 restart backend-api
```

## Dijalankan Local
Prequirements
```
sudo apt update
sudo apt install mysql-server mysql-client
sudo mysql

CREATE USER 'admin'@'localhost' IDENTIFIED BY 'admin';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;

ALTER USER 'admin'@'localhost' IDENTIFIED WITH mysql_native_password BY 'admin';
FLUSH PRIVILEGES;

CREATE DATABASE money_tracker;
USE money_tracker;

execute
money-tracker-app/backend/create_table.sql

ALTER USER 'admin'@'localhost' IDENTIFIED WITH mysql_native_password BY 'admin';
FLUSH PRIVILEGES;
```

## Backend


```
export GOOGLE_CLOUD_PROJECT="id-project-gcp-anda"
npm start
```
## Frontend
```
composer install
php -S localhost:8080 -t .
```
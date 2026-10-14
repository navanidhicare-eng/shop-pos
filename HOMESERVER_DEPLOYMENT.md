# 🏠 Homeserver Docker & PostgreSQL Deployment Guide

This guide explains how to deploy your **Shop POS & Oil Mill Management System** onto your Homeserver using **Docker**, **Docker Compose**, and **PostgreSQL**.

---

## 🏗️ Architecture Overview

The system runs as an integrated stack via Docker:

```
                  ┌──────────────────────────────────────────────┐
                  │                 HOMESERVER                   │
                  │                                              │
  Browser / Phone │   ┌──────────────────────────────────────┐   │
  ───────────────►│:5000  shop_app (Node.js 20 Alpine)       │   │
                  │   │   ├── REST API (/api/*)              │   │
                  │   │   ├── Admin Web Dashboard (/)        │   │
                  │   │   ├── Staff POS Web App (/pos)       │   │
                  │   │   └── Uploads (/uploads) ────────────┼───┼──► Persistent Host Folder
                  │   └──────────────────┬───────────────────┘   │    (./admin_web/uploads)
                  │                      │ Internal Network      │
                  │                      ▼                       │
                  │   ┌──────────────────────────────────────┐   │
                  │:5432  shop_postgres (Postgres 16 Alpine) │   │
                  │   │   └── shop_db ───────────────────────┼───┼──► Persistent Docker Volume
                  │   └──────────────────────────────────────┘   │    (shop_postgres_data)
                  └──────────────────────────────────────────────┘
```

---

## 🚀 Quick Start (Recommended: Dockerized PostgreSQL)

### 1. Copy Project Files to Your Homeserver

Transfer the project directory to your homeserver via Git, `rsync`, or `scp`:
```bash
# On your homeserver (e.g. into ~/shop-app)
cd ~/shop-app
```

### 2. Check the `.env` Configuration File

Verify that `.env` exists in the project root:
```bash
cp .env.example .env
```

Default `.env` configuration:
```env
NODE_ENV=production
APP_PORT=5000

DB_TYPE=postgres
DB_HOST=postgres
DB_PORT=5432
DB_PORT_HOST=5432
DB_NAME=shop_db
DB_USER=postgres
DB_PASSWORD=shop_secure_password_123

DB_SSL=false
```

> 💡 *Feel free to customize `DB_PASSWORD` in `.env` if desired.*

### 3. Build & Start the Containers

Run the following command on your Homeserver:
```bash
docker compose up -d --build
```

Docker will:
1. Start the PostgreSQL 16 container and initialize the persistent data volume.
2. Wait for PostgreSQL to pass its health check (`pg_isready`).
3. Build the Node.js app container with the backend API, Admin Web dashboard, and prebuilt Staff POS Web app.
4. Automatically create all 14 PostgreSQL database tables and seed initial default catalog items and admin accounts.

### 4. Check Container Status

```bash
docker compose ps
```
Both `shop_postgres` and `shop_app` should display status `Up (healthy)`.

---

## 📱 Accessing Your Application

Find your homeserver local IP address (e.g. `192.168.1.100` or `hostname.local`):

| Service | URL | Default Credentials |
| :--- | :--- | :--- |
| **Admin Web Dashboard** | `http://<HOMESERVER-IP>:5000/` | **Username:** `admin`<br>**Password:** `admin123` |
| **Staff POS (Billing & Sales)** | `http://<HOMESERVER-IP>:5000/pos/` | **Username:** `staff`<br>**Password:** `staff123` |
| **Backend REST API** | `http://<HOMESERVER-IP>:5000/api/` | — |
| **PostgreSQL Database** | `<HOMESERVER-IP>:5432` | **User:** `postgres`<br>**Database:** `shop_db` |

---

## 🔄 Scenario B: Using PostgreSQL Already Installed on Homeserver Host

If you downloaded and installed PostgreSQL directly on your Homeserver OS (instead of running it in a Docker container):

1. Edit `.env`:
   ```env
   DB_HOST=host.docker.internal
   DB_PORT=5432
   DB_USER=postgres
   DB_PASSWORD=your_host_postgres_password
   DB_NAME=shop_db
   ```
2. In your host PostgreSQL `pg_hba.conf`, ensure connections from the Docker bridge subnet (`172.17.0.0/16` or `all`) are allowed with password.
3. Start only the app container:
   ```bash
   docker compose up -d --build app
   ```

---

## 📦 Migrating Existing SQLite Data (`shop.db`) into PostgreSQL

If you already have items, sales history, customer khata balances, or batches in `backend/shop.db` on your computer, you can migrate everything into PostgreSQL with one command:

### Option 1: Run via Docker (on Homeserver)
```bash
docker compose exec app npm run migrate:sqlite-to-pg
```

### Option 2: Run directly from Host (with Node.js)
```bash
cd backend
npm run migrate:sqlite-to-pg
```

The script will:
- Read all records from `shop.db`.
- Insert them into PostgreSQL respecting primary keys and foreign key constraints.
- Reset the PostgreSQL `SERIAL` sequences to the highest existing IDs.

---

## 🛡️ Backup & Maintenance

### Creating a Database Backup
```bash
# Creates a compressed SQL dump timestamped with today's date
docker exec -t shop_postgres pg_dump -U postgres shop_db > backup_$(date +%F).sql
```

### Restoring a Database Backup
```bash
cat backup_YYYY-MM-DD.sql | docker exec -i shop_postgres psql -U postgres shop_db
```

### Viewing Real-Time Logs
```bash
# View backend app logs
docker compose logs -f app

# View postgres logs
docker compose logs -f postgres
```

### Updating the App
Whenever you make updates to the code:
```bash
git pull
docker compose up -d --build
```
Your database and uploaded images will stay completely intact because they are stored in persistent Docker volumes.

# 🏪 Shop POS & Oil Mill Management System

A full-stack Point of Sale (POS), Inventory, Production Batches, Customer Khata Ledger, and Milling Job-work system built with:
- **Backend**: Node.js, Express, PostgreSQL / SQLite (dual database engine)
- **Admin Dashboard**: Web UI (`/`)
- **Staff Mobile / POS**: Flutter Web application (`/pos/`)
- **Deployment**: Docker & Docker Compose with PostgreSQL 16

---

## 🚀 Quick Deployment with Docker

To deploy on your server with Docker and PostgreSQL:

```bash
# 1. Start PostgreSQL & the Node.js application stack
docker compose up -d --build

# 2. View running containers
docker compose ps
```

- **Admin Web Dashboard**: `http://<SERVER-IP>:5000/`
- **Staff POS Billing Web**: `http://<SERVER-IP>:5000/pos/`
- **API Endpoint**: `http://<SERVER-IP>:5000/api/`

For detailed setup instructions, host PostgreSQL configuration, and data migration, see:
👉 **[HOMESERVER_DEPLOYMENT.md](HOMESERVER_DEPLOYMENT.md)**

---

## 🛠️ Local Development (Without Docker)

You can also run locally on your PC using either PostgreSQL or local SQLite:

```bash
cd backend
npm install

# Run with SQLite (default if no Postgres host specified):
npm start
```

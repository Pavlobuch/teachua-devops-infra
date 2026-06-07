# Docker Implementation

## Overview

The TeachUA application is containerized into three services:

| Service | Base Image | Port | Description |
|---|---|---|---|
| `db` | `mysql:8.0` | 3306 | MySQL database with schema and seed data |
| `backend` | `eclipse-temurin:17-jre-alpine` | 8080 | Spring Boot REST API (WAR artifact) |
| `frontend` | `nginx:alpine` | 80 (mapped to 3000) | React SPA served via Nginx |

---

## Repository & File Locations

All three repos must be siblings in the same parent directory:

```
TeachUA/
├── backend-Pavlobuch/
│   ├── Dockerfile                  ← backend image definition
│   ├── data.sql                    ← DB schema + seed data (mounted into MySQL)
│   └── src/
├── frontend-Pavlobuch/
│   ├── Dockerfile                  ← frontend image definition (multi-stage)
│   └── nginx.conf                  ← Nginx config for SPA routing
└── devops-infra/
    └── docker/
        ├── docker-compose.yml      ← orchestrates all three services
        └── .env.example            ← template for required environment variables
```

---

## Dockerfiles

### Backend — `backend-Pavlobuch/Dockerfile`

Two-stage build:

**Stage 1 — Build (`maven:3.9-eclipse-temurin-17`)**
- Copies `pom.xml` first and runs `mvn dependency:go-offline` to cache Maven dependencies as a separate Docker layer. Rebuilds only when `pom.xml` changes.
- Copies source code and runs `mvn clean package -DskipTests` to produce `target/dev.war`.

**Stage 2 — Run (`eclipse-temurin:17-jre-alpine`)**
- Copies only the WAR artifact from the build stage — no Maven, no source code in the final image.
- JRE-only Alpine base keeps the image small (~200 MB vs ~600 MB with JDK).
- Starts the app with `java -jar app.war` on port `8080`.

Environment variables required at runtime (injected via docker-compose):

| Variable | Example Value | Description |
|---|---|---|
| `JDBC_DRIVER` | `com.mysql.cj.jdbc.Driver` | JDBC driver class name |
| `DATASOURCE_URL` | `jdbc:mysql://db:3306/teachua?...` | Full JDBC connection URL |
| `DATASOURCE_USER` | `teachua_user` | DB username |
| `DATASOURCE_PASSWORD` | `teachua_password` | DB password |
| `JWT_SECRET` | `your-secret` | Secret key for JWT token signing |

These map directly to placeholders in `src/main/resources/application.properties`.

---

### Frontend — `frontend-Pavlobuch/Dockerfile`

Two-stage build:

**Stage 1 — Build (`node:16-alpine`)**
- Copies `package.json` and `package-lock.json` first and runs `npm ci` to cache the `node_modules` layer. Rebuilds only when dependencies change.
- Accepts `REACT_APP_ROOT_SERVER` as a build argument and sets it as an environment variable before running `npm run build` (uses `craco build` under the hood).
- **Important:** React environment variables are embedded into the JavaScript bundle at build time, not at runtime. The value of `REACT_APP_ROOT_SERVER` must be the URL that the **browser** uses to reach the backend — not a Docker internal hostname.

**Stage 2 — Serve (`nginx:alpine`)**
- Copies the compiled static files from `build/` into the Nginx web root.
- Copies `nginx.conf` to configure SPA routing (`try_files $uri /index.html` ensures React Router handles navigation).

Build argument required:

| Argument | Example Value | Description |
|---|---|---|
| `REACT_APP_ROOT_SERVER` | `http://localhost:8080` | Backend API base URL (browser-visible) |

---

### Nginx Config — `frontend-Pavlobuch/nginx.conf`

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

The `try_files` directive is critical for React Router. Without it, refreshing a non-root page (e.g. `/clubs/5`) returns a 404 because Nginx looks for a file at that path.

---

## Docker Compose — `docker/docker-compose.yml`

### Service: `db`

- Uses the official `mysql:8.0` image — no custom Dockerfile.
- `data.sql` from the backend repo is mounted into `/docker-entrypoint-initdb.d/`. MySQL runs all `.sql` files in that directory on first container start (only when the data volume is empty).
- A healthcheck (`mysqladmin ping`) prevents the backend from starting before the database is ready.
- Data is persisted in a named volume `db_data` so it survives container restarts.

### Service: `backend`

- Built from `backend-Pavlobuch/Dockerfile` using `../../backend-Pavlobuch` as the build context.
- `depends_on: db: condition: service_healthy` — waits for the MySQL healthcheck to pass before starting.
- JDBC URL uses `db` as the hostname (Docker's internal DNS resolves service names within a compose network).

### Service: `frontend`

- Built from `frontend-Pavlobuch/Dockerfile`.
- `REACT_APP_ROOT_SERVER` is passed as a build argument so it is baked into the React bundle during the image build.
- Host port `3000` maps to container port `80` (Nginx).

---

## Environment Variables Setup

Copy the example file and fill in your values before running:

```bash
cd devops-infra/docker
cp .env.example .env
# edit .env with real values
```

`.env.example` contents:

```
MYSQL_ROOT_PASSWORD=rootpassword
MYSQL_USER=teachua_user
MYSQL_PASSWORD=teachua_password
JWT_SECRET=your-super-secret-jwt-key-change-this
REACT_APP_ROOT_SERVER=http://localhost:8080
```

Docker Compose automatically loads `.env` from the same directory as `docker-compose.yml`.

---

## Running the Stack

All commands are run from `devops-infra/docker/`:

```bash
# Build all images and start containers in the background
docker compose up -d --build

# View logs for all services
docker compose logs -f

# View logs for a specific service
docker compose logs -f backend

# Stop all containers (keeps volumes)
docker compose down

# Stop and delete all data (volumes included)
docker compose down -v
```

### First-run sequence

1. MySQL starts and initializes: creates the `teachua` database, then runs `data.sql` (schema + seed data).
2. Healthcheck confirms MySQL is ready.
3. Backend starts: Spring Boot connects to `db:3306`, Hibernate runs `ddl-auto=update` (adjusts schema if needed).
4. Frontend starts: Nginx serves the pre-built React bundle.

---

## Building Images Individually

```bash
# Backend
cd backend-Pavlobuch
docker build -t teachua-backend:latest .

# Frontend
cd frontend-Pavlobuch
docker build \
  --build-arg REACT_APP_ROOT_SERVER=http://localhost:8080 \
  -t teachua-frontend:latest .
```

---

## Useful Commands

```bash
# List running containers
docker ps

# Shell into a running container
docker exec -it teachua-backend sh
docker exec -it teachua-db bash

# Connect to MySQL inside the container
docker exec -it teachua-db mysql -u teachua_user -p teachua

# Inspect the db_data volume
docker volume inspect docker_db_data

# Remove all stopped containers and dangling images
docker system prune

# Check image sizes
docker images | grep teachua
```

---

## Troubleshooting

### Backend fails to connect to the database

- Check that the `db` healthcheck is passing: `docker compose ps`
- Verify `.env` has the correct `MYSQL_USER` / `MYSQL_PASSWORD`
- The JDBC URL must use `db` as the host (not `localhost`), since `localhost` inside the backend container refers to the backend itself

### `data.sql` is not being executed

- The MySQL init scripts only run when the data volume is empty (first startup)
- If the volume already exists from a previous run, destroy it: `docker compose down -v` then `docker compose up -d --build`

### Frontend shows blank page or API calls fail

- `REACT_APP_ROOT_SERVER` is baked in at **build time** — if you change it in `.env`, you must rebuild the frontend image: `docker compose up -d --build frontend`
- The value must be reachable from the **browser** (not Docker internal network). Use `http://localhost:8080` for local development.

### React Router routes return 404 on refresh

- Ensure `nginx.conf` is being copied into the image correctly and contains the `try_files` directive.

---

## Notes for Future Stages

- **Stage 3 (Terraform / AWS):** Replace `mysql:8.0` with an RDS endpoint; remove the `db` service from compose.
- **Stage 5 (Jenkins):** The CI pipeline will run `docker compose build` and push images to a registry (ECR or Docker Hub).
- **Stage 7 (Kubernetes):** Each service in `docker-compose.yml` maps to a Kubernetes `Deployment` + `Service`. The `db_data` volume becomes a `PersistentVolumeClaim`. `REACT_APP_ROOT_SERVER` becomes a build-time arg passed from the Jenkins pipeline.
- **Image tagging convention:** Use `git rev-parse --short HEAD` as the image tag in CI for traceability (e.g. `teachua-backend:a1b2c3d`).

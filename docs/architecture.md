# Architecture Overview


## Goal

Build a complete DevOps platform for a full-stack application using modern DevOps tools and practices.F

## Fronted technology stack:
Front-end written on: React JS;
Required Tools: nodejs 16 version.

Technical Details
Front-end written on: React JS;
Required Tools: nodejs 16 version.
Running the Project
Execute the following command in the frontend directory:
npm install
Write the path to the backend server into the REACT_APP_ROOT_SERVER environment variable for example
http://localhost:8080
Run the Project:
After successful building you could run the front-end in dev mode:

npm run start
The application will start on 3000 port.
To build the front-end to production run command:

npm run build
    The application will appear in the ./build folder.
    Copy all files in your webserver and configure it.


## Backend and database technology stack
Back-end programming language: Java
Database: MariaDB/MySQL
Required Tools: Java 17, Maven 3.6.3

You can create a database using a command
create database teachua2 character set utf8 collate utf8_bin;
The ./data.sql file contains a script for creating tables and populating initial data.

Database Configuration
In the application's configuration file

./backend/src/main/resources/application.properties
the path and database connection details are obtained from the following environment variables:

JDBC_DRIVER - the full name of the database connection driver; for example
org.mariadb.jdbc.Driver
com.mysql.cj.jdbc.Driver
DATASOURCE_URL - connection string to the database; for example
jdbc:mariadb://127.0.0.1:3306/teachua
jdbc:mysql://127.0.0.1:3306/teachua?useUnicode=true&serverTimezone=UTC
DATASOURCE_USER - user name;
DATASOURCE_PASSWORD - user password;
Before starting, make sure that the MariaDB/MySQL database contains an empty database.

Running the Project
Build the Project:
Execute the following command in the backend directory:

mvn clean package
Run the Project:
After successful building, run the .jar file in the ./target folder:

java -jar target/dev.war
The application will start on 8080 port.

---

## Target Architecture

Developer
↓
GitHub
↓
Jenkins
↓
Docker Build
↓
AWS Infrastructure
↓
Kubernetes (K3s)
↓
Application
↓
Splunk Forwarder / HEC
↓
Splunk (dedicated EC2)

---

## Components

### Frontend

User-facing web application.

Responsibilities:

* User Interface
* Client-side logic
* API communication

---

### Backend

REST API service.

Responsibilities:

* Business logic
* Database communication
* API endpoints

---

### Database

MySQL database used by the backend service.

Responsibilities:

* Data storage
* Data persistence

---

### Docker

Used for application containerization.

Responsibilities:

* Consistent environments
* Reproducible deployments

---

### Docker Compose

Used for local development.

Responsibilities:

* Multi-container orchestration
* Local testing

---

### Terraform

Infrastructure as Code.

Responsibilities:

* AWS provisioning
* Network configuration
* Infrastructure automation

---

### Ansible

Configuration management.

Responsibilities:

* Server configuration
* Software installation
* Operational automation

---

### Jenkins

CI/CD platform.

Responsibilities:

* Build automation
* Deployment automation
* Pipeline execution

---

### Kubernetes (K3s)

Container orchestration platform.

Responsibilities:

* Application deployment
* Scaling
* Service management

---

### Splunk

Monitoring and log analysis platform. Runs self-hosted on a dedicated EC2 instance, separate from the K3s app node.

Responsibilities:

* Log aggregation and indexing
* Infrastructure monitoring
* Application monitoring
* Dashboards and alerting

---

### Fluent Bit

Log forwarder deployed as a Kubernetes DaemonSet on the K3s app node.

Responsibilities:

* Tail container logs (`/var/log/containers/*.log`)
* Enrich logs with Kubernetes metadata
* Ship logs to Splunk over HTTP Event Collector (HEC)

Full design, including indexes and HEC setup, is in [monitoring.md](monitoring.md).

---

## Design Principles

* Infrastructure as Code
* Automation First
* Cost Optimization
* Reproducibility
* Observability
* Security by Default

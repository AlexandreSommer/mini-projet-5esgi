#!/bin/bash

# Définir le répertoire du projet
PROJECT_DIR=$(pwd)

# 1. Création des répertoires nécessaires pour les fichiers Docker et Kubernetes
mkdir -p $PROJECT_DIR/webapp
mkdir -p $PROJECT_DIR/k8s

# 2. Création du Dockerfile pour l'application Flask
cat <<EOF > $PROJECT_DIR/webapp/Dockerfile
FROM python:3.6-alpine
WORKDIR /opt
COPY . .
RUN pip install flask
EXPOSE 8080
ENV ODOO_URL=https://www.odoo.com/
ENV PGADMIN_URL=https://www.pgadmin.org/
ENTRYPOINT ["python", "app.py"]
EOF

# 3. Création de l'application Flask (fichier app.py minimal)
cat <<EOF > $PROJECT_DIR/webapp/app.py
from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def home():
    odoo_url = os.getenv('ODOO_URL', 'https://www.odoo.com/')
    pgadmin_url = os.getenv('PGADMIN_URL', 'https://www.pgadmin.org/')
    return f"<h1>Welcome to IC Group WebApp</h1><p>Odoo URL: <a href='{odoo_url}'>{odoo_url}</a></p><p>PgAdmin URL: <a href='{pgadmin_url}'>{pgadmin_url}</a></p>"

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
EOF

# 4. Création des fichiers Kubernetes dans le répertoire k8s
# a. PostgreSQL Deployment
cat <<EOF > $PROJECT_DIR/k8s/postgres.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: icgroup
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:13
          envFrom:
            - secretRef:
                name: odoo-secret
          ports:
            - containerPort: 5432
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: odoo-db-data
  namespace: icgroup
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

# b. Odoo Deployment
cat <<EOF > $PROJECT_DIR/k8s/odoo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: odoo
  namespace: icgroup
spec:
  replicas: 1
  selector:
    matchLabels:
      app: odoo
  template:
    metadata:
      labels:
        app: odoo
    spec:
      containers:
        - name: odoo
          image: odoo:13.0
          env:
            - name: POSTGRES_USER
              value: postgres
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: odoo-secret
                  key: password
          ports:
            - containerPort: 8069
---
apiVersion: v1
kind: Service
metadata:
  name: odoo
  namespace: icgroup
spec:
  ports:
    - port: 8069
      targetPort: 8069
  selector:
    app: odoo
EOF

# c. pgAdmin Deployment
cat <<EOF > $PROJECT_DIR/k8s/pgadmin.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgadmin
  namespace: icgroup
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pgadmin
  template:
    metadata:
      labels:
        app: pgadmin
    spec:
      containers:
        - name: pgadmin
          image: dpage/pgadmin4:latest
          env:
            - name: PGADMIN_EMAIL
              valueFrom:
                secretKeyRef:
                  name: pgadmin-secret
                  key: pgadmin-email
            - name: PGADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: pgadmin-secret
                  key: pgadmin-password
          ports:
            - containerPort: 80
          volumeMounts:
            - mountPath: /pgadmin4
              name: pgadmin-volume
              subPath: servers.json
---
apiVersion: v1
kind: Service
metadata:
  name: pgadmin
  namespace: icgroup
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: pgadmin
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: pgadmin-config
  namespace: icgroup
data:
  servers.json: |
    {
      "Servers": {
        "1": {
          "Name": "Odoo Database",
          "Group": "Server Group 1",
          "Port": 5432,
          "Username": "postgres",
          "Host": "postgres",
          "SSLMode": "prefer",
          "MaintenanceDB": "postgres"
        }
      }
    }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pgadmin-data
  namespace: icgroup
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# d. Flask WebApp Deployment
cat <<EOF > $PROJECT_DIR/k8s/webapp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: icgroup
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: webapp
          image: <dockerhub_user>/ic-webapp:1.0
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: webapp
  namespace: icgroup
spec:
  ports:
    - port: 8080
      targetPort: 8080
  selector:
    app: webapp
EOF

# 5. Créer le secret Odoo et pgAdmin
kubectl create secret generic odoo-secret --from-literal=password=odoo123 --namespace=icgroup
kubectl create secret generic pgadmin-secret --from-literal=pgadmin-email=admin@icgroup.com --from-literal=pgadmin-password=admin123 --namespace=icgroup

# 6. Appliquer les fichiers de configuration Kubernetes
kubectl apply -f $PROJECT_DIR/k8s/ -n icgroup

echo "Tout a été créé et les ressources ont été déployées !"

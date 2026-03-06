# Go + MariaDB Demo App (Simple)

Sehr einfache REST API mit **einer Tabelle**:
- Tabelle: `demo_names`
- Felder: `id` (Primary Key), `name`

## Endpoints
- `GET /healthz`
- `GET /names`
- `POST /names`

## Auf k3d laufen lassen

Voraussetzung: Dein k3d-Cluster laeuft und MariaDB ist als `my-mariadb` im gleichen Namespace installiert.

CloudPirates MariaDB installieren (falls noch nicht vorhanden):

```bash
helm install my-mariadb oci://registry-1.docker.io/cloudpirates/mariadb \
  --set auth.rootPassword=workshop123 \
  --set auth.database=workshop
```

```bash
# aus dem Repo-Root
cd examples/go-mariadb-demo

# 1) App-Image lokal bauen
docker build -t go-mariadb-demo:latest .

# 2) Image in den k3d-Cluster importieren
# Clustername hier: workshop (anpassen falls anders)
k3d image import go-mariadb-demo:latest

# 3) DB Schema + Seed per Job im Cluster erstellen
kubectl apply -f k8s/db-init-job.yaml
kubectl wait --for=condition=complete --timeout=120s job/go-mariadb-demo-init

# 4) App deployen
kubectl apply -f k8s/app.yaml
kubectl rollout status deployment/go-mariadb-demo

# 5) API lokal testen (port-forward)
kubectl port-forward svc/go-mariadb-demo 8080:8080

# 6) service vom typ loadbalancer
k create svc go-maridb-demo --tcp=8080
```

## Zweites Kubernetes Beispiel: Init Container statt Job

Dieses Beispiel nutzt nur `k8s-initcontainer/app.yaml`.
Der Init Container legt Schema/Tabelle an und seeded **nur**, wenn `demo_names` leer ist.

```bash
cd examples/go-mariadb-demo

# optional: erstes Beispiel aufraeumen
kubectl delete deployment/go-mariadb-demo service/go-mariadb-demo job/go-mariadb-demo-init --ignore-not-found

# Init-Container-Variante deployen
kubectl apply -f k8s-initcontainer/app.yaml
kubectl rollout status deployment/go-mariadb-demo-initcontainer

# API testen
kubectl port-forward svc/go-mariadb-demo-initcontainer 8080:8080
```

In einem zweiten Terminal:

```bash
curl http://127.0.0.1:8080/healthz
curl http://127.0.0.1:8080/names

curl -X POST http://127.0.0.1:8080/names \
  -H 'Content-Type: application/json' \
  -d '{"name":"Olivia"}'
```

## Manuell per SQL (Alternative)

```bash
kubectl port-forward svc/my-mariadb 3306:3306

mysql -h 127.0.0.1 -P 3306 -u root -pworkshop123 < schema.sql
mysql -h 127.0.0.1 -P 3306 -u root -pworkshop123 < seed.sql
```

## Lokal ohne Kubernetes

```bash
go run ./cmd/api
```

oder als Container:

```bash
docker run --rm \
  --network host \
  -e APP_PORT=8080 \
  -e DB_HOST=127.0.0.1 \
  -e DB_PORT=3306 \
  -e DB_USER=root \
  -e DB_PASSWORD=workshop123 \
  -e DB_NAME=workshop \
  go-mariadb-demo:latest
```

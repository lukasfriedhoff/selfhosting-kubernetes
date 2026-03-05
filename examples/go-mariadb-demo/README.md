# Go + MariaDB Demo App (Simple)

Sehr einfache REST API mit **einer Tabelle**:
- Tabelle: `demo_names`
- Felder: `id` (Primary Key), `name`

## Endpoints
- `GET /healthz`
- `GET /names`
- `POST /names`

## 1) Schema + Demo-Daten laden

Wenn MariaDB bereits im Cluster via Helm laeuft (`my-mariadb`):

```bash
kubectl port-forward svc/my-mariadb 3306:3306
```

In einem zweiten Terminal:

```bash
cd examples/go-mariadb-demo

mysql -h 127.0.0.1 -P 3306 -u root -p workshop123 < schema.sql
mysql -h 127.0.0.1 -P 3306 -u root -pworkshop123 < seed.sql
```

## 2) App lokal starten

```bash
cd examples/go-mariadb-demo
go run ./cmd/api
```

## 3) App als Docker-Container starten

```bash
cd examples/go-mariadb-demo

docker build -t go-mariadb-demo:latest .

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

## 4) API testen

```bash
curl http://127.0.0.1:8080/healthz
curl http://127.0.0.1:8080/names

curl -X POST http://127.0.0.1:8080/names \
  -H 'Content-Type: application/json' \
  -d '{"name":"Olivia"}'
```

# CNPG Demo: PostgreSQL 17 -> 18 Major Upgrade (Autopilot Style)

Dieses Beispiel zeigt, was ein Operator fuer dich uebernimmt:
- Start eines 3-Node PostgreSQL-Clusters auf Version 17
- Daten persistieren
- Major Upgrade auf Version 18 durch **eine** deklarative Aenderung (`spec.imageName`)
- CNPG orchestriert den Upgrade-Job und den Neustart der Instanzen

Hinweis zu "Autopilot":
- In den Operator Capability Levels ist automatisches Upgrade ein Merkmal von Level 2 (Seamless Upgrades).
- Level 5 ("Auto Pilot") geht noch weiter (z. B. automatische horizontale Skalierung/optimierte Konfiguration).

## Dateien
- `00-namespace.yaml`
- `01-app-secret.yaml`
- `02-cluster-pg17.yaml`
- `03-cluster-pg18.yaml`

## Voraussetzung
- OLM Operator Lifecycle Manager
- CNPG Operator ist installiert (Namespace `cnpg-system`)
- Zugriff auf ein Kubernetes Cluster (z. B. k3d)

Falls OLM noch fehlt:

```bash
curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.41.0/install.sh | bash -s v0.41.0
```

Falls CNPG noch fehlt:

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm upgrade --install cnpg cnpg/cloudnative-pg --namespace cnpg-system --create-namespace
```

## 1) PostgreSQL 17 Cluster erstellen

```bash
cd examples/cnpg-major-upgrade-autopilot

kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-app-secret.yaml
kubectl apply -f 02-cluster-pg17.yaml

kubectl -n cnpg-upgrade-demo get cluster,pods,svc
kubectl -n cnpg-upgrade-demo wait --for=condition=Ready cluster/workshop-pg --timeout=600s
```

## 2) Demo-Daten anlegen und Version pruefen

```bash
kubectl -n cnpg-upgrade-demo port-forward svc/workshop-pg-rw 5432:5432
```

In zweitem Terminal:

```bash
psql "host=127.0.0.1 port=5432 dbname=app user=app password=app123" <<'SQL'
SELECT version();

CREATE TABLE IF NOT EXISTS people (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

TRUNCATE TABLE people;
INSERT INTO people (name) VALUES ('k8s'), ('kubernetes'), ('kUbErNeTeZ');

SELECT * FROM people ORDER BY id;
SQL
```

## 3) Upgrade auf PostgreSQL 18 triggern

```bash
kubectl apply -f 03-cluster-pg18.yaml
```

Das ist die zentrale Operator-Demo:
- Du aenderst nur den gewuenschten Zielzustand (`imageName`)
- CNPG startet den Major-Upgrade-Job und reconciled den Cluster danach automatisch
- Das Major Upgrade ist **offline**: waehrenddessen gibt es Downtime.

## 4) Upgrade beobachten

```bash
kubectl -n cnpg-upgrade-demo get cluster workshop-pg -w
```

Parallel in einem zweiten Terminal:

```bash
kubectl -n cnpg-upgrade-demo get jobs -w
kubectl -n cnpg-upgrade-demo get pods -w

# Upgrade-Job-Name ermitteln (endet auf -major-upgrade) und Logs ansehen
kubectl -n cnpg-upgrade-demo get jobs
kubectl -n cnpg-upgrade-demo logs job/<major-upgrade-job-name> --tail=200
```

## 5) Nach Upgrade validieren

```bash
kubectl -n cnpg-upgrade-demo port-forward svc/workshop-pg-rw 5432:5432
```

In zweitem Terminal:

```bash
psql "host=127.0.0.1 port=5432 dbname=app user=app password=app123" <<'SQL'
SELECT version();
SELECT * FROM people ORDER BY id;
SQL
```

Erwartung:
- `version()` zeigt PostgreSQL 18.x
- Tabelle `people` und Daten sind weiterhin vorhanden

## Cleanup

```bash
kubectl delete namespace cnpg-upgrade-demo
```

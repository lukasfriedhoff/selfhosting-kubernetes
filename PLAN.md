# WIP: Workshop Overview Selfhosting mit Kubernetes

## Prerequisites

- Eigene Hardware/System mit docker runtime (16GB RAM)
- Grundlegendes Verstaendnis von Docker bzw. Containern

## Installation k3d (15min)

Wir starten gemeinsam unser erstes Kubernetes Cluster mit k3d (Wrapper um k3s).
Dann nutzen wir `kubectl` um einen groben Überblick über das erstellte Kubernetes Cluster zu gewinnnen.

## Erste Schritte

### kubectl (10min)

Was ist kubectl und wie benutze ich es:
kubectl get ...
kubectl api-resources
kubectl explain

### Overview Deployment, StatefulSet, DaemonSet

#### Unterschiede Deployment, StatefulSet, DaemonSet (10min)

#### Deployment erstellen und anlegen (15min)

Basic example deployment und image waehlen, restart behaviour, init container, bla blub
Manuelle Aenderungen am Deployment machen...
Port forward und dann Interaktion mit deployment


#### Service erstellen (20min)

Typen und Unterschiede zwischen NodePort, ClusterIP und LoadBalancer,...
Service anlegen und via IP durch Service zum Deployment kommen.

### Beispiel Postgres Cluster mit CNPG Operator (30min)

#### Was ist ein Operator

Wer macht sowas, was bringt mir das, welche Typen gibt es(BasicInstall, SeamlessUpgrade, FullLifecycle, DeepInsights, AutoPilot)?
CNPG ist Autopilot. Welche CRDs liefert CNPG, wie verwende ich sie?

#### CNPG Installieren und Konfigurieren

##### Helm

Was ist helm, was ist ein helm repo,...?
CNPG Helm Repo hinzufuegen und CNPG via Helm Release installieren.

##### CRD postgresql.cnpg.io/Cluster

Postgres Cluster definieren und deployen durch benutzen der CNPG CRD(anlegen einer CR).

##### Verbinden mit Postgres Cluster

Via cli, unterschied zw. read-only und rw.

## Puffer fuer Fragen und Details (20min)


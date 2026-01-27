# WIP: Workshop Overview Selfhosting mit Kubernetes

## Prerequisites

- Eigene Hardware/System mit docker runtime (16GB RAM)
- Grundlegendes Verstaendnis von Docker bzw. Containern

```
docker to be able to use k3d at all

    Note: k3d v5.x.x requires at least Docker v20.10.5 (runc >= v1.0.0-rc93) to work properly



## Installation k3d (15min) und Cluster erstellen

Wir starten gemeinsam unser erstes Kubernetes Cluster mit k3d (Wrapper um k3s).
Dann nutzen wir `kubectl` um einen groben Überblick über das erstellte Kubernetes Cluster zu gewinnnen.

```bash
# member of docker group?
groups | grep docker

# add user to docker group
usermod -a -G docker $USER
newgrp docker

# is docker service running?
systemctl status docker

# k3d installation via shell script or see other install methods https://k3d.io/stable/#install-current-latest-release
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# create default cluster
k3d cluster create

```

## Erste Schritte

### kubectl (10min)



Was ist kubectl und wie benutze ich es:
kubectl get ...
kubectl api-resources
kubectl explain

```bash
# install on ubuntu 24.x via
sudo snap install kubectl --classic

# check cluster info
kubectl cluster-info
kubectl get nodes

# why does this work? k3d cluster create created a kubeconfig at
less ~/.kube/config

# what workloads/pods/containers run on the default cluster?
kubectl get pods --all-namespaces
# should return (core)dns, helm installs, local-path-provisioner(storage), metrics server and loadbalancer(traefik)

# install k9s or openlense or both

k create deployment --image hashicorp/http-echo test

k port-forward -n default test-* 5678

```

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


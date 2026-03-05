# WIP: Workshop Overview Selfhosting mit Kubernetes

## Zielbild
Nach dem Workshop koennen Teilnehmende:
- ein lokales Kubernetes-Cluster mit k3d aufsetzen,
- Workloads mit `kubectl` deployen und debuggen,
- Services (ClusterIP, NodePort, LoadBalancer) praktisch vergleichen,
- ein Stateful-Workload (MariaDB via Helm) betreiben,
- einen PostgreSQL-Cluster mit dem CloudNativePG-Operator verstehen und starten.

## Voraussetzungen / Prerequisites
- Linux-Host mit Docker Runtime (mind. 16 GB RAM empfohlen)
- Grundlegendes Docker/Container-Verstaendnis


```sh
Note: k3d v5.x.x requires at least Docker v20.10.5 (runc >= v1.0.0-rc93) to work properly

# Docker muss laufen
systemctl status docker

# User fuer Docker berechtigen
sudo usermod -aG docker "$USER"
groups | grep docker
newgrp docker
# oder neu einloggen
```

## Agenda (ca. 2h)
1. Setup: k3d + kubectl (15 min)
2. kubectl Grundlagen (20 min)
3. Deployment + Services (15 min)
4. Q&A / Puffer (10 min)
5. Helm + MariaDB (25 min)
6. CloudNativePG Operator + Postgres Cluster (25 min)
7. Q&A / Puffer (10 min)

## 1) Installation k3d (15min) und Cluster erstellen


### k3d installieren und Cluster erstellen

Wir starten gemeinsam unser erstes Kubernetes Cluster mit k3d (Wrapper um k3s).
Dann nutzen wir `kubectl` um einen groben Überblick über das erstellte Kubernetes Cluster zu gewinnnen.

```bash
# k3d installation via shell script or see other install methods https://k3d.io/stable/#install-current-latest-release
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# create default cluster
k3d cluster create
k3d cluster ls

```

### kubectl installation - first steps

Was ist [kubectl](https://kubernetes.io/docs/reference/kubectl/)

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

#create an alias for kubectl - current terminal or .bashrc
alias k=kubectl
complete -o default -F __start_kubectl k

```
und wie benutze ich es?

```sh
kubectl get ?
kubectl api-resources
kubectl explain
```

### UI Tools - install k9s or openlense or both

[k9s - tui](https://k9scli.io/topics/install/)

``` sudo apt install k9s ```


[Headlamp - Webinterface]

```sh
sudo apt install flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install io.kinvolk.Headlamp
flatpak run io.kinvolk.Headlamp
```


[OpenLens - gui](https://github.com/MuhammedKalkan/OpenLens)


### Overview Deployment, StatefulSet, DaemonSet

#### Unterschiede Deployment, StatefulSet, DaemonSet (10min)

#### Deployment erstellen und anlegen (15min)

Basic example deployment und image waehlen, restart behaviour, init container, ...
Manuelle Aenderungen am Deployment machen...
Port forward und dann Interaktion mit deployment

```sh
k create deployment --image hashicorp/http-echo test
kubectl rollout status deployment/test


k port-forward -n default test-* 5678

k edit deployment test

```

#### Service erstellen (20min)

Typen und Unterschiede zwischen NodePort, ClusterIP und LoadBalancer,...
Service anlegen und via IP durch Service zum Deployment kommen.

```sh
k create service test nodeport test --tcp=5678

k get service test
#note the port >30000
curl ...
#test connection

#fails in k3d because network is isolated - add nodeport port forward
k3d cluster list
#should return
#k3s-default
k3d cluster edit --port-add 30913:30913@server:0 k3s-default

curl http://localhost:30913

#better use loadbalancer
k create service loadbalancer --help
k create svc loadbalancer test2 --tcp=5678
k get svc test2 #note the external ip e.g. 172.18.0.2

curl http://172.18.0.2:5678
# does this work?
k get -o yaml svc test2 > test2.svc.yaml
#selector fooo - try again


```
### Beispiel MySQL DB

#### Helm

[helm.sh](https://helm.sh/)

[install helm](https://helm.sh/docs/intro/install)

[artifacthub](https://artifacthub.io)

#### MariaDB erstellen

```sh
helm install my-mariadb oci://registry-1.docker.io/cloudpirates/mariadb

#port forward
k port-forward my-maridb-0 3306:3306

#mysql client install
sudo apt install mysql-client

mysql -u root -p -h 127.0.0.1
#do stuff

#show helm releases
helm list
helm get all my-maridb
helm get values my-maridb

```

#### Example Go App that connects to db as docker container


### Beispiel Postgres Cluster mit CNPG Operator (30min)

#### Was ist ein Operator

Wer macht sowas, was bringt mir das, welche Typen gibt es(BasicInstall, SeamlessUpgrade, FullLifecycle, DeepInsights, AutoPilot)?
CNPG ist Autopilot. Welche CRDs liefert CNPG, wie verwende ich sie?

[operatorhub](https://operatorhub.io)

#### CNPG Installieren und Konfigurieren



Was ist helm, was ist ein helm repo,...?
CNPG Helm Repo hinzufuegen und CNPG via Helm Release installieren.



##### CRD postgresql.cnpg.io/Cluster

Postgres Cluster definieren und deployen durch benutzen der CNPG CRD(anlegen einer CR).

rw vs r vs ro?
rw ist master des clusters
ro sind alle instanzen die nur lesen koennen
r ist eine beliebige instanz die lesen kann, also auch der rw master

```bash
sudo apt install postgresql
sudo systemctl stop postgresql

```

##### Verbinden mit Postgres Cluster

Via cli, unterschied zw. read-only und rw.

```
k port-forward -n defaul .?
psql -h 127.0.0.1 -u app -w

```

## Puffer fuer Fragen und Details (20min)


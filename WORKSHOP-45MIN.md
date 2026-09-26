# Workshop 45 min: Selfhosting mit Kubernetes

Trainer-Skript fuer eine 45-Minuten-Session mit ca. 12 Teilnehmenden.
Langfassung (2 h, mit Helm, MariaDB und CloudNativePG): [PLAN.md](./PLAN.md).

Zielgruppe: kennt Docker und ein Terminal, will Dienste zuhause betreiben, sie im LAN
erreichen und keine Daten verlieren. Kein CKA, keine Operator-Capability-Levels.

**Der Satz, der haengen bleiben soll:**
> Der Pod ist Wegwerfware. Service, Ingress und PVC sind es nicht — deshalb funktioniert das Ganze.

**45 min sind Wall Clock, Setup inklusive.** Das Cluster wird gemeinsam in der Session gebaut;
es gibt keine Hausaufgabe und kein "docker pull vor der Anreise". Der Preis dafuer steht im
Budget unten: vierzehn Minuten. Wer hinterherhinkt, arbeitet den [Kuerzungsplan](#kuerzungsplan) ab —
in genau dieser Reihenfolge.

---

## Minutenbudget

| min | Block | Wer tippt |
|---:|---|---|
| 0–2 | [Rahmen: Nextcloud ist das Ziel](#02-min--rahmen-nextcloud-ist-das-ziel) | niemand |
| 2–16 | [Setup gemeinsam: Werkzeuge, Cluster, Uptime Kuma sofort starten](#216-min--setup-gemeinsam) | alle |
| 16–24 | [Deployment: der Pod ist Wegwerfware](#1624-min--deployment-der-pod-ist-wegwerfware) | alle |
| 24–34 | [Service und Ingress: eine Adresse, zwei Dienste](#2434-min--service-und-ingress-eine-adresse-zwei-dienste) | alle + 1 Trainer-Demo |
| 34–42 | [Persistenz: der Pod stirbt, die Daten nicht](#3442-min--persistenz-der-pod-stirbt-die-daten-nicht) | alle |
| 42–45 | [Wie geht es weiter + Q&A](#4245-min--wie-geht-es-weiter) | niemand |

Summe: 2 + 14 + 8 + 10 + 8 + 3 = **45**. Fragen werden **im Block** beantwortet, nicht gesammelt —
dafuer ist der Wrap kurz.

Faustregel fuer den Trainer: **zwei Saetze pro Begriff, dann weiter.** Jeder Block hat unten eine
Tabelle *Symptom → Ursache → Fix*. Wenn eine Meldung nicht drinsteht, ist sie ein Q&A nach der
Session, kein Live-Debugging.

---

## Voraussetzungen

Genau zwei Dinge, und beide bringen die Leute schon mit:

1. **Ein laufendes Docker**, das der eigene User benutzen darf (Docker Desktop zaehlt).
2. **Ein Terminal** und `git` bzw. `curl`.

Kein root, kein Paketmanager, kein snap: `scripts/setup-tools.sh` legt `kubectl`, `helm`, `k3d`
und `k9s` als Binaries in `~/.local/bin` und richtet Completions fuer bash und zsh ein.

### Der Einzeiler fuer die Einladungsmail

```bash
docker run --rm hello-world && echo "BEREIT - mehr musst du nicht vorbereiten"
```

Sieht man `BEREIT`, ist alles getan. Sieht man `permission denied` auf
`/var/run/docker.sock`, dann **vor** der Session einmal:

```bash
sudo usermod -aG docker "$USER"   # danach ab- und neu anmelden, nicht nur newgrp
```

Das ist die einzige Sache, die eine neue Anmeldung braucht — und damit die einzige, die live
teuer waere.

### Trainer-Vorbereitung (15 Minuten am Vortag, plus ein USB-Stick)

- **Das Repo muss auf dem oeffentlichen Remote liegen.** Die Teilnehmenden klonen von GitHub,
  nicht von der internen Forgejo-Instanz — `scripts/` **und** `manifests/` muessen also
  wirklich gepusht sein (`git push github develop`), nicht nur lokal committed. Pre-Flight:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/lukasfriedhoff/selfhosting-kubernetes/HEAD/manifests/10-uptime-kuma.yaml | head -1
  ```
  Muss eine Kommentarzeile liefern. Liefert es `404`, ist der Workshop nicht durchfuehrbar.
- **Uplink rechnen — das ist das groesste Risiko der Session, groesser als jedes Kubernetes-Thema.**
  Es sind nicht "nur die 1,8 GB von Kuma". Pro Person laufen vier Downloads:

  | Was | Pro Person |
  |---|---:|
  | Werkzeuge (`kubectl`, `helm`, `k3d`, `k9s`) | ~135 MB |
  | k3s-Node-Image + k3d-Proxy-Image | ~95 MB |
  | `traefik/whoami:v1.12.0` | ~5 MB |
  | `louislam/uptime-kuma:1` | ~149 MB |
  | **Summe** | **~385 MB** |

  Bei 12 Personen sind das **~4,7 GB**. Ein *ausgelasteter* 50-Mbit-Uplink schafft das in
  **~12,5 Minuten** — und zwar nur, wenn er tatsaechlich 50 Mbit liefert und sonst niemand im
  Raum etwas anderes tut. Das Setup-Budget von 14 Minuten ist genau darauf gerechnet. Wenn das
  WLAN unbekannt ist: Plan B vorher aufbauen, nicht live improvisieren.
- **Plan B: LAN statt Internet.** Zwei Wege, beide vorher testen. Variante 2 ist die, die immer
  funktioniert.

  (`WS_PORT` in den Befehlen unten ist die Host-Port-Variable aus dem
  [Setup-Block](#216-min--setup-gemeinsam) — die Teilnehmenden haben sie dann gesetzt.)

  *Variante 1 — Trainer-Registry als docker.io-Mirror* (spart die 154 MB Container-Images pro
  Person, nicht das k3s-Node-Image):
  ```bash
  # Trainer, einmal:
  docker run -d --name ws-mirror -p 5000:5000 \
    -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io registry:2
  # Cache vorwaermen (Pull-Through-Proxy liefert jeden docker.io-Pfad):
  docker pull 192.168.44.10:5000/traefik/whoami:v1.12.0
  docker pull 192.168.44.10:5000/louislam/uptime-kuma:1
  ```
  Teilnehmende bekommen eine Datei `ws-registries.yaml`:
  ```yaml
  mirrors:
    docker.io:
      endpoint:
        - "http://192.168.44.10:5000"
  ```
  und legen das Cluster damit an:
  ```bash
  k3d cluster create homelab --image rancher/k3s:v1.36.4-k3s1 \
    -p "${WS_PORT}:80@loadbalancer" --registry-config ws-registries.yaml
  ```
  Alternativ eine k3d-eigene Registry mit `k3d cluster create ... --registry-use k3d-ws-cache:5000`
  — dann muessen die Images aber mit Registry-Prefix adressiert werden, also nur, wenn du die
  Manifeste sowieso anpasst.

  *Variante 2 — USB-Stick oder Trainer-Laptop, ohne Netz* (deckt **alles** ab, auch das
  k3s-Node-Image, das Docker auf dem Host zieht und den kein Mirror abfaengt):
  ```bash
  # Trainer, einmal:
  docker pull rancher/k3s:v1.36.4-k3s1
  docker pull traefik/whoami:v1.12.0
  docker pull louislam/uptime-kuma:1
  docker save rancher/k3s:v1.36.4-k3s1 traefik/whoami:v1.12.0 louislam/uptime-kuma:1 \
    -o ws-images.tar
  ```
  ```bash
  # Teilnehmende, vom Stick:
  docker load -i ws-images.tar
  k3d cluster create homelab --image rancher/k3s:v1.36.4-k3s1 -p "${WS_PORT}:80@loadbalancer"
  k3d image import traefik/whoami:v1.12.0 louislam/uptime-kuma:1 -c homelab
  ```
  Das funktioniert, weil beide Tags fest sind: Kubernetes nimmt bei einem gepinnten Tag
  `imagePullPolicy: IfNotPresent` und benutzt das importierte Image. Bei `:latest` waere es
  `Always` und der Import waere wertlos — einer von mehreren Gruenden, warum hier nichts
  `:latest` heisst. **Auf denselben Stick gehoeren die vier Binaries** aus `setup-tools.sh`
  (~135 MB): nach `~/.local/bin` kopieren, dann nur noch `./scripts/setup-tools.sh --check`.
- **Pruefen, dass die drei Image-Tags ueberhaupt ziehbar sind** (Tags werden geloescht, Registries
  haben Ausfaelle — das willst du am Vortag wissen, nicht in Minute 14):
  ```bash
  docker manifest inspect rancher/k3s:v1.36.4-k3s1  >/dev/null && echo "ok k3s"
  docker manifest inspect traefik/whoami:v1.12.0    >/dev/null && echo "ok whoami"
  docker manifest inspect louislam/uptime-kuma:1    >/dev/null && echo "ok kuma"
  ```
  Drei `ok`-Zeilen, sonst Plan B.
- **Eigenes Terminal gross, Schrift gross, Prompt kurz.** Ein Block ist eine Trainer-Demo
  auf dem Projektor.
- **Kuerzungsplan ausgedruckt neben die Tastatur.**

---

## 0–2 min — Rahmen: Nextcloud ist das Ziel

**Trainer redet, niemand tippt.**

> Das Ziel, mit dem die meisten hier sitzen, heisst **Nextcloud im eigenen Netz**: eigene Dateien,
> eigener Kalender, eigene Adresse mit HTTPS. Wir installieren es heute bewusst *nicht* —
> `nextcloud:31-apache` sind 461 MB, dazu eine Postgres-Datenbank mit 112 MB, ein Secret, ein PVC
> und eine Erstinstallation, die minutenlang laeuft. Das frisst die Session und versteckt genau
> die Objekte, um die es geht. Nextcloud besteht naemlich aus vier Bausteinen, und die bauen wir
> heute an einem Dienst, der in Sekunden startet. Am Ende steht Nextcloud als Schritt 1 auf dem
> Zettel — und dann kannst du jede Zeile davon lesen.

Warum nicht `docker compose`? Compose kann genau eine Sache nicht: den Zustand
wiederherstellen, den du wolltest. Kubernetes ist ein Regelkreis — du beschreibst den
Soll-Zustand, das Cluster haelt ihn.

Vokabular, 30 Sekunden, nicht mehr:

| Objekt | In einem Satz |
|---|---|
| **Pod** | ein oder mehrere Container, kurzlebig, ersetzbar |
| **Deployment** | "halte n Pods von diesem Image am Leben" |
| **Service** | stabiler Name und stabile IP vor wechselnden Pods |
| **Ingress** | HTTP-Router von aussen nach innen, nach Hostname |
| **PVC** | angeforderter Speicher, ueberlebt den Pod |

Am Ende der Session laufen zwei Dienste unter zwei Hostnamen auf **einem** Port, und einer von
beiden hat Daten, die einen Pod-Tod ueberleben.

---

## 2–16 min — Setup gemeinsam

**Alle tippen.** Ziel: jeder hat ein Cluster, und der 149-MB-Download laeuft im Hintergrund,
bevor wir mit dem Erklaeren anfangen.

**Das Budget ist 14 Minuten, und es ist knapp, nicht grosszuegig:** 2–3 min Werkzeuge,
**1–4 min Cluster**, ~1 min Kuma und Nachschauen, der Rest ist Puffer fuer die zwei bis drei
Leute, bei denen Docker streikt. Wer hier 16 Minuten braucht, streicht spaeter nach
[Kuerzungsplan](#kuerzungsplan) — das ist eingeplant, kein Scheitern.

```bash
git clone https://github.com/lukasfriedhoff/selfhosting-kubernetes.git
cd selfhosting-kubernetes
./scripts/setup-tools.sh
```

Ohne `git`:

```bash
curl -fsSL https://github.com/lukasfriedhoff/selfhosting-kubernetes/archive/HEAD.tar.gz | tar xz
cd selfhosting-kubernetes-*
```

Der Lauf dauert 2–3 Minuten (vier Downloads, ~135 MB, mit Checksummen-Pruefung). Danach Shell neu
laden und selbst pruefen:

```bash
source ~/.bashrc      # zsh: source ~/.zshrc - oder einfach einen neuen Tab oeffnen
./scripts/setup-tools.sh --check
```

**Zu sehen:** fuenf gruene `ok`-Zeilen (`docker`, `kubectl`, `helm`, `k3d`, `k9s`) und
`ok docker laeuft und ist nutzbar`. Exit-Code 0.

### Ein Name fuer den Host-Port: `WS_PORT`

Alles, was spaeter von aussen ins Cluster geht, benutzt **diese eine Variable**. Einmal setzen,
jetzt, alle zusammen — dann gibt es im ganzen Rest der Session kein Suchen-und-Ersetzen:

```bash
export WS_PORT=8080
```

**Ist 8080 auf deinem Rechner belegt** (haeufig: Jenkins, Tomcat, ein anderes Docker-Projekt),
dann **jetzt** `export WS_PORT=18080` — oder 28080, egal — und weiter wie alle anderen. Ab hier
steht in jedem Befehl `$WS_PORT` und nie wieder eine Zahl. Zwei Dinge dazu:

- Die Variable lebt in **dieser** Shell. Neuer Tab? `export WS_PORT=...` erneut, oder gleich
  `echo 'export WS_PORT=8080' >> ~/.bashrc`.
- Der **Browser** kann keine Variable. Wenn wir spaeter eine URL eintippen, liefert
  `echo $WS_PORT` die Zahl, die dort hingehoert.

### Cluster

Jetzt das Cluster — eine Zeile, absichtlich ohne Zeilenumbrueche:

```bash
k3d cluster create homelab --image rancher/k3s:v1.36.4-k3s1 -p "${WS_PORT}:80@loadbalancer"
```

**Das dauert 1–4 Minuten, nicht 20 Sekunden.** Der Befehl zieht zuerst das k3s-Node-Image
(`rancher/k3s`, mit dem k3d-Proxy zusammen ~95 MB) und startet danach erst das Cluster. Die
"17–40 Sekunden", die man in Blogposts und in meinen eigenen Testlaeufen liest, gelten fuer einen
**warmen Docker-Cache** — den hat hier niemand. Zwoelf Leute, ein WLAN: vier Minuten sind normal.

**Zu sehen:** zuletzt `Cluster 'homelab' created successfully!`.

```bash
kubectl get nodes
```

**Zu sehen:** eine Zeile, `Ready`, `control-plane`, Version `v1.36.4+k3s1`.

### Und sofort Uptime Kuma starten

Ohne Pause, der wichtigste Befehl des Setups:

```bash
kubectl apply -f manifests/10-uptime-kuma.yaml
kubectl get pvc
```

**Zu sehen:** vier Zeilen `created` — und beim PVC:

```
NAME        STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
kuma-data   Pending                                      local-path     <unset>                 1s
```

`Pending` ist **richtig**, nicht kaputt: `local-path` benutzt
`volumeBindingMode: WaitForFirstConsumer`, das Volume entsteht erst, wenn klar ist, auf welchem
Node der Pod laeuft. In zehn Sekunden steht dort `Bound`.

**Trainer sagt jetzt den Satz, der die naechsten achtzehn Minuten kauft:**
"Ab hier laedt im Hintergrund ein 149-MB-Image. Das ist Absicht. Wir reden weiter, und wenn wir
in Minute 32 zurueckkommen, ist es da."

### Symptom → Ursache → Fix

| Symptom | Ursache | Fix |
|---|---|---|
| `permission denied ... /var/run/docker.sock` | User nicht in Gruppe `docker` | `sudo usermod -aG docker "$USER"`, **abmelden und neu anmelden**. Live: neben jemanden setzen, nicht debuggen |
| `k3d: command not found` nach dem Setup | Shell nicht neu geladen | `source ~/.bashrc` bzw. neuer Tab |
| `port is already allocated` bei `cluster create` | Host-Port belegt | `export WS_PORT=18080`, dann `cluster create` erneut. Nur diese eine Stelle, alles Weitere benutzt `$WS_PORT` |
| spaeter `connection refused` auf `127.0.0.1:$WS_PORT` | `WS_PORT` in einem neuen Tab nicht gesetzt (ist dann leer) | `echo $WS_PORT` — leer? `export WS_PORT=...` mit dem Wert, mit dem das Cluster angelegt wurde. Zur Not `docker ps \| grep serverlb` zeigt die Zahl |
| `cluster create` haengt Minuten bei `Starting new tools node` | genau der beschriebene Image-Pull | erwartet, weiterreden. `docker pull rancher/k3s:v1.36.4-k3s1` in einem zweiten Tab zeigt den Fortschritt |
| Cluster existiert schon (`failed to create cluster`) | Rest aus einem frueheren Versuch | `k3d cluster delete homelab` und neu |
| `kubectl get nodes` zeigt `v1.21.x` | k3d **<= 5.8.3** faellt auf einen hartcodierten k3s-Stand von 2021 zurueck, wenn der Lookup auf `update.k3s.io` scheitert (Konferenz-WLAN!) | genau darum sind k3d v5.9.0 (via Setup-Skript) **und** `--image rancher/k3s:v1.36.4-k3s1` gepinnt. Mit dem `--image`-Flag kann es nicht passieren |
| `kubectl apply` sagt `no such file or directory` | falsches Verzeichnis | `cd` ins geklonte Repo; `ls manifests/` muss zwei `.yaml` zeigen |
| `error: You must be logged in to the server` | kubeconfig zeigt auf ein fremdes Cluster | `kubectl config use-context k3d-homelab` |

---

## 16–24 min — Deployment: der Pod ist Wegwerfware

**Ziel in einem Satz:** zeigen, dass ein geloeschter Pod von allein zurueckkommt — der eine
Unterschied zu `docker run`, an dem alles haengt.

**Alle tippen.**

```bash
kubectl create deployment web --image traefik/whoami:v1.12.0
kubectl get pods -l app=web
```

`traefik/whoami` sind 5 MB und starten sofort — deshalb ist das hier und nicht Kuma der Dienst
zum Herumspielen. Der Tag ist gepinnt: bei `:latest` setzt Kubernetes `imagePullPolicy: Always`
und zieht bei jedem Start neu.

Und jetzt der Moment, fuer den die Leute gekommen sind:

```bash
kubectl delete pod -l app=web
kubectl get pods -l app=web
```

**Zu sehen:** `pod "web-85875947cf-4nldt" deleted from default namespace`, und direkt danach ein
Pod mit **neuem Namen**
und `AGE 1s`. Zwischen den beiden Befehlen liegt ungefaehr eine Sekunde.

> **Das ist der Unterschied zu `docker run`.** Du hast den Pod nicht verloren, du hast ihn ersetzt
> bekommen. Geloescht hast du eine Instanz eines Wunsches, nicht den Wunsch selbst. Der Wunsch
> heisst Deployment.

Diagnose-Handwerkszeug, in dieser Reihenfolge — das sind die Befehle, die zuhause 90 % aller
Fragen beantworten:

```bash
kubectl logs deploy/web
kubectl describe deploy/web
```

**Zu sehen:** bei `logs` eine Zeile `Starting up on port 80`; bei `describe` ganz unten
`Events:` mit `ScalingReplicaSet`. **Immer zuerst die Events lesen, nicht die Logs.**

> **Stolperfalle, die jeder trifft: `exec` braucht eine Shell im Image.**
> `kubectl exec -it deploy/web -- sh` scheitert mit
> `exec: "sh": executable file not found in $PATH`. `traefik/whoami` ist 5 MB und hat keine Shell
> — wie fast alle modernen Images (distroless). Der Ausweg ist ein Wegwerf-Pod, und den zeigt
> gleich der Trainer.

**Trainer-Demo, 30 Sekunden, sonst nichts:** `k9s` starten, `:pods` eintippen, `l` fuer Logs,
`d` fuer describe, `Esc`, dann `:q`. Kein Lernziel — nur damit alle wissen, dass es existiert und
dass `describe` und `logs` darin zwei Tastendruecke sind. Das ist der erste Punkt auf dem
[Kuerzungsplan](#kuerzungsplan).

### Symptom → Ursache → Fix

| Symptom | Ursache | Fix |
|---|---|---|
| `ImagePullBackOff` bei `web` | Tippfehler im Image oder kein Netz | `kubectl describe pod -l app=web \| tail -5`. Notausgang: `kubectl delete deploy web` und `kubectl apply -f manifests/20-whoami.yaml` |
| `kubectl get pods` zeigt nach dem Delete **zwei** `web`-Pods | der alte terminiert noch | eine Sekunde warten, nochmal schauen. Genau deshalb steht hier `-l app=web` und kein Pod-Name |
| `error: name cannot be provided when a selector is specified` | `-l` und Pod-Name gemischt | eins von beiden, nie beides |
| `deployments.apps "web" already exists` | Block schon einmal gelaufen | `kubectl delete deploy web` oder einfach weitermachen |

---

## 24–34 min — Service und Ingress: eine Adresse, zwei Dienste

**Ziel in einem Satz:** ein Service ist ein DNS-Name plus eine Liste von Endpoints, ein Ingress
ist ein Router davor — und am Ende laufen zwei Dienste auf **einem** Port, unterschieden allein
durch den Hostnamen. Das ist der Homelab-Moment.

Zehn Minuten, zwei Haelften, kein Luftholen dazwischen.

### Teil 1: der Service — Name statt IP

**Alle tippen:**

```bash
kubectl expose deployment web --port 80
kubectl describe svc web
```

**Zu sehen** — es zaehlen genau zwei Zeilen:

```
Selector:                 app=web
Endpoints:                10.42.0.12:80
```

`Selector` sagt, welche Pods gemeint sind. `Endpoints` sagt, welche es tatsaechlich gibt.

> **Die Regel fuers Homelab, einmal gesagt und nie vorgefuehrt:** Dienst nicht erreichbar →
> `kubectl describe svc <name>` → ist `Endpoints` **leer**, ist es *immer* der Selector oder ein
> nicht laufender Pod. **Nie** das Netzwerk. (Die haeufigste Quelle dafuer:
> `kubectl create service` leitet den Selector vom **Service-Namen** ab, `kubectl expose` vom
> **Workload**.)

Dass `http://web` und `http://kuma` als Adressen funktionieren, kommt von **coredns** — dem
cluster-internen DNS, der seit Minute 2 in `kube-system` mitlaeuft, ohne dass wir ihn
installiert haetten.

#### Trainer-Demo: der Wegwerf-Pod (Projektor, NICHT alle)

**Bewusst nur der Trainer.** Zwoelf Leute in einer interaktiven Shell heisst: zwoelf Leute
vergessen `exit`, und beim zweiten Versuch kommt `pods "tmp" already exists`.

```bash
kubectl run tmp -it --rm --image alpine:3 -- sh
```

Im Pod:

```sh
getent hosts web
wget -qO- http://web
wget -qO- http://kuma
exit
```

**Zu sehen:** `getent` liefert `10.43.104.214 web.default.svc.cluster.local ... web` — der Name
existiert cluster-intern. `wget http://web` liefert den whoami-Dump inklusive
`Hostname: web-...`. Und `http://kuma` antwortet mit `302 Found, Location: /dashboard` —
das Image ist also fertig geladen, ohne dass wir es angeschaut haben. Kommt hier nichts, zieht
Kuma noch; dafuer steht weiter unten ein explizites `kubectl wait`.

Merksatz: ein Service ist ein **DNS-Name plus eine Liste von Endpoints**. Nichts weiter.

> Randnotiz fuer den Fall, dass jemand den vollen Namen tippt: `wget http://web.default.svc.cluster.local`
> scheitert in Alpine mit `bad address`, `wget http://web.default.svc.cluster.local.` (Punkt am
> Ende!) funktioniert. Grund ist `ndots:5` in `/etc/resolv.conf` plus musl, das anders als glibc
> nicht auf den absoluten Namen zurueckfaellt. Kurze Namen benutzen, Thema erledigt.

### Teil 2: der Ingress — zwei Dienste, eine Adresse

Den Reverse-Proxy bringt k3s selbst mit: **traefik** laeuft in `kube-system` als Ingress
Controller und haengt an Port 80 des Nodes — genau dort kommt unser gemappter Host-Port
`$WS_PORT` heraus.

Uptime Kuma hat seinen Ingress schon aus `manifests/10-uptime-kuma.yaml`. Es fehlt nur der
fuer `web`:

```bash
kubectl create ingress web --class=traefik --rule="whoami.k3d.localhost/*=web:80"
kubectl get ingress
```

**Zu sehen:** zwei Zeilen, beide mit `CLASS traefik` und nach 5–15 Sekunden einer IP in
`ADDRESS` (in k3d etwas wie `172.20.0.2`).

```bash
curl -H 'Host: whoami.k3d.localhost' http://127.0.0.1:$WS_PORT
curl -s -o /dev/null -w 'kuma: HTTP %{http_code}\n' -H 'Host: kuma.k3d.localhost' http://127.0.0.1:$WS_PORT
curl -s -o /dev/null -w 'ohne Host: HTTP %{http_code}\n' http://127.0.0.1:$WS_PORT
```

**Zu sehen:**

- der whoami-Dump mit `Host: whoami.k3d.localhost` und den `X-Forwarded-*`-Headern von Traefik,
- `kuma: HTTP 302` — Kuma leitet auf `/dashboard`, das ist die richtige Antwort, nicht 200,
- `ohne Host: HTTP 404` — Traefik antwortet, kennt aber ohne Hostnamen keine Route.

**Diese drei Zeilen sind der ganze Block.** Gleiche IP, gleicher Port, drei verschiedene
Ergebnisse, Unterschied ist ausschliesslich der `Host`-Header. Genau das ist host-basiertes
Routing; alles andere ist DNS-Kosmetik.

### Bevor jemand den Browser aufmacht: einmal warten

**Alle tippen — dieser Schritt wird nicht uebersprungen:**

```bash
kubectl wait --for=condition=Ready pod -l app=kuma --timeout=300s
```

**Zu sehen:** `pod/kuma-... condition met`. Erst danach oeffnet irgendwer einen Browser — sonst
sehen drei Leute einen Fehler, und wir debuggen einen Download. Die 300 Sekunden sind absichtlich
grosszuegig: zwoelf gleichzeitige Pulls von 149 MB durch ein Konferenz-WLAN dauern. Wer hier in
den Timeout laeuft, hat ein Netzproblem, kein Kubernetes-Problem —
`kubectl describe pod -l app=kuma | tail -5` zeigt dann `Pulling`.

Jetzt der Blick, der es glaubwuerdig macht — **im Browser**, mit der Portnummer aus
`echo $WS_PORT`:

```
http://kuma.k3d.localhost:8080
```

(Wer `WS_PORT` oben geaendert hat, tippt hier die Zahl aus `echo $WS_PORT` statt 8080 —
das ist die einzige Stelle in der ganzen Session, an der die Zahl von Hand hin muss.)

**Zu sehen:** der Einrichtungsbildschirm von Uptime Kuma. Ein echter Homelab-Dienst, hinter einem
Hostnamen, aus vier YAML-Objekten. **Noch nichts einrichten** — das kommt im naechsten Block.

**So sieht das zuhause aus** (ein Satz, nicht vorfuehren): ein Wildcard-DNS-Record
`*.home.example.com` zeigt auf die LoadBalancer-IP von Traefik, cert-manager holt das Zertifikat,
und ab dann ist jeder neue Dienst genau diese eine `Ingress`-Zeile. Das ist der eigentliche
Gewinn gegenueber Compose plus handgepflegtem Reverse-Proxy.

### Symptom → Ursache → Fix

| Symptom | Ursache | Fix |
|---|---|---|
| `services "web" already exists` | `expose` zweimal gelaufen — **oder** jemand hat in Minute 16–24 den Notausgang `kubectl apply -f manifests/20-whoami.yaml` benutzt, der Service und Ingress gleich mitanlegt | `kubectl delete svc web`, dann neu — oder einfach weitermachen, der Service ist ja schon da |
| `Endpoints` leer, obwohl der Pod laeuft | Label passt nicht zum Selector | `kubectl get pods --show-labels` mit `kubectl describe svc` vergleichen |
| `pods "tmp" already exists` | jemand hat bei der Trainer-Demo mitgetippt und `exit` vergessen | `kubectl delete pod tmp --now` |
| `ADDRESS` bleibt leer | IngressClass greift nicht | `kubectl get ingressclass`; ist `traefik` nicht Default, ist `--class=traefik` genau der Fix (steht oben schon drin) |
| kein `traefik`-Pod in `kube-system` | Cluster noch nicht fertig (k3s installiert Traefik per Job; `helm-install-traefik-*` auf `Completed` ist gesund) | 20 s warten, dann `kubectl get pods -n kube-system` erneut |
| `HTTP 404` **mit** korrektem Host-Header | Ingress zeigt auf einen Service, der keine Endpoints hat | zurueck zu `kubectl describe svc web` |
| `HTTP 503` | Service da, Pod (noch) nicht ready | `kubectl get pods`; bei Kuma einfach warten |
| `HTTP 000` / `connection refused` | Host-Port nicht durchgereicht oder `$WS_PORT` leer | `echo $WS_PORT` pruefen; `docker ps \| grep serverlb` muss `0.0.0.0:<WS_PORT>->80/tcp` zeigen. Sonst Cluster mit `-p` neu anlegen |
| Browser: `kuma.k3d.localhost` loest nicht auf | glibc kennt keine Sonderregel fuer `*.localhost`; mit `systemd-resolved` geht es, mit dnsmasq oft nicht | `echo '127.0.0.1 whoami.k3d.localhost kuma.k3d.localhost' \| sudo tee -a /etc/hosts`. Deshalb steht die `curl -H`-Variante **zuerst**: die braucht gar kein DNS |
| Browser landet auf `https://` oder in der Suchmaschine, curl geht | Browser erzwingt HTTPS-Upgrade bzw. deutet den Namen als Suchbegriff | `http://` explizit tippen und Enter statt Auswahl; im Zweifel bleibt es bei den `curl`-Zeilen, die beweisen dasselbe |

---

## 34–42 min — Persistenz: der Pod stirbt, die Daten nicht

**Ziel in einem Satz:** beweisen, dass ein PVC den Pod ueberlebt — an einem Dienst, der eine
echte Datenbankdatei hat.

Zuerst hinschauen, was da ueberhaupt liegt:

```bash
kubectl get pvc
kubectl exec deploy/kuma -- ls -la /app/data
```

**Zu sehen:** PVC auf `Bound`, `RWO`, `1Gi`, StorageClass `local-path` — und im Verzeichnis
`kuma.db`, `kuma.db-shm`, `kuma.db-wal`. Das ist SQLite. Ein Dienst, eine Datei, ein PVC:
der haeufigste Fall im Homelab.

Woher die StorageClass kommt, ohne dass wir sie angelegt haben: **local-path-provisioner**, auch
das ein Bordmittel von k3s und die Default-`StorageClass` — er macht aus einem PVC ein
Verzeichnis auf genau diesem einen Node.

Jetzt die Markierung setzen und den Pod umbringen:

```bash
kubectl exec deploy/kuma -- sh -c 'echo "workshop 2026" > /app/data/beweis.txt'
kubectl delete pod -l app=kuma
kubectl wait --for=condition=Ready pod -l app=kuma --timeout=120s
kubectl exec deploy/kuma -- cat /app/data/beweis.txt
```

**Zu sehen:** `kubectl delete` blockiert ~5 Sekunden (es wartet, bis der Pod wirklich weg ist),
`kubectl wait` meldet nach weiteren ~7 Sekunden `condition met`, und `cat` gibt
`workshop 2026` aus. **Neuer Pod, alte Datei.**

> **Warum genau diese vier Zeilen, und nicht `rollout status`:** `kubectl rollout status` kann
> Erfolg melden, waehrend der alte Pod noch terminiert — dann greift das folgende
> `kubectl exec deploy/kuma` den sterbenden Pod und scheitert mit
> `unable to upgrade connection`. `kubectl delete` **blockiert** dagegen per Default, bis das
> Objekt weg ist, und `kubectl wait --for=condition=Ready` wartet auf den Nachfolger. Zusammen
> ist das rennfrei.
>
> Auch **nicht** benutzen: `kubectl wait --for=delete pod -l app=kuma`. Das schnappt sich beim
> Start eine Liste aller passenden Pods — und der Ersatz-Pod traegt dasselbe Label. Dann wartet
> der Befehl bis zum Timeout auf die Loeschung eines Pods, der gerade gestartet ist, und endet mit
> `timed out waiting for the condition`. Ein Rennen, das man oft verliert: im Test hier scheiterten
> zwei von drei Laeufen. Wenn du unbedingt auf die Loeschung warten willst, dann auf einen
> **Namen**:
> ```bash
> POD=$(kubectl get pod -l app=kuma -o name)
> kubectl delete "$POD" --wait=false
> kubectl wait --for=delete "$POD" --timeout=60s
> kubectl wait --for=condition=Ready pod -l app=kuma --timeout=120s
> ```

**Trainer-Demo, 20 Sekunden:** wo die Daten wirklich liegen.

```bash
docker exec k3d-homelab-server-0 ls /var/lib/rancher/k3s/storage
```

Ein Verzeichnis auf **einem** Node. Damit ist die wichtigste Homelab-Konsequenz gesagt:
`local-path` heisst, die Daten kleben an dieser einen Maschine. Sobald du einen zweiten Node
hast, startet der Pod dort und findet ein leeres Verzeichnis — ab da brauchst du Longhorn, NFS
oder Ceph. Und Backups macht `local-path` keine.

Ein Blick in die Datei, die das alles beschreibt — drei Bloecke, nicht mehr:

```bash
grep -n -A4 -E 'kind: PersistentVolumeClaim|volumeMounts:|persistentVolumeClaim:' manifests/10-uptime-kuma.yaml
```

Drei Stellen muessen zusammenpassen, und das ist die ganze Kunst: das PVC hat einen **Namen**,
der Container hat einen `volumeMount` mit `mountPath`, und das `volumes`-Feld verbindet beide.

### Symptom → Ursache → Fix

| Symptom | Ursache | Fix |
|---|---|---|
| `unable to upgrade connection` bei `exec` | Pod noch nicht ready oder gerade weg | `kubectl wait --for=condition=Ready pod -l app=kuma --timeout=120s`, dann nochmal |
| `kubectl wait`: `no matching resources found` | zu schnell nach dem Delete, Ersatz-Pod noch nicht erzeugt | Befehl einfach erneut ausfuehren |
| PVC haengt auf `Terminating` beim Aufraeumen | Finalizer `kubernetes.io/pvc-protection`, solange ein Pod es benutzt | Schutz, kein Bug: erst `kubectl delete deploy kuma`, dann `kubectl delete pvc kuma-data` |
| Kuma-Pod bleibt `0/1 Running` | readinessProbe noch in der Kulanzzeit (bis 70 s beim ersten Start) | warten. `kubectl describe pod -l app=kuma \| tail -5` zeigt, ob es die Probe ist |
| `Multi-Attach error` / neuer Pod mountet nicht | zwei Pods wollen ein RWO-Volume | genau deshalb steht `strategy: type: Recreate` im Manifest. Wer es auf RollingUpdate aendert, baut sich das ein |

---

## 42–45 min — Wie geht es weiter

**Niemand tippt.** Zwei Begriffe benennen, damit sie nicht fremd sind:

- **Helm** ist fertiges YAML von anderen Leuten, parametrisiert. Entscheidend ist nur die
  Erkenntnis: Helm erzeugt **genau die Objekte, die wir heute gebaut haben**.
  `helm get manifest <name>` zeigt sie, `kubectl describe` reparierst du damit selbst.
  Verzeichnis: [artifacthub.io](https://artifacthub.io).
- **Operatoren** sind ein Schritt weiter: ein Controller, der einen Dienst *betreibt* statt ihn
  nur zu installieren — bei Datenbanken uebernimmt z. B. **CloudNativePG** Failover, Backups und
  Major-Upgrades. Das ist Tag 2, siehe [PLAN.md](./PLAN.md).

Der realistische Weg nach Hause, in dieser Reihenfolge:

1. **Nextcloud** — das Ziel von Minute 0. Du brauchst dafuer exakt die vier Objekte von heute,
   plus zwei neue Begriffe: ein **Secret** fuer das Datenbankpasswort und ein zweites Deployment
   fuer **Postgres**. Realistisch ein Abend, und du kannst am Ende jede Zeile lesen. Startpunkt:
   das offizielle Chart via [artifacthub.io](https://artifacthub.io), danach **unbedingt**
   `helm get manifest nextcloud` lesen — dort findest du PVC, Service und Ingress wieder.
2. **Denselben Dienst nochmal von Hand**, ohne Chart. Ab hier entzifferst du fremde Charts statt
   ihnen zu vertrauen. Anfangspunkt ist `manifests/20-whoami.yaml` aus diesem Repo: dieselben
   Objekte, die wir getippt haben, als Datei.
3. **Raus aus k3d**, rein auf echte Hardware: k3s auf einem Rechner oder einer VM. Jetzt brauchst
   du echtes DNS (Wildcard auf die Cluster-IP), **MetalLB** fuer LAN-IPs und **cert-manager**
   fuer Zertifikate.
4. **Zweiter Node** — und hier kommt die Speicherfrage von Minute 34 zurueck. `local-path` traegt
   das nicht mehr: Longhorn, oder NFS, wenn ein NAS da ist.
5. **Erst dann** GitOps (Flux/Argo) und Operatoren. Vorher hast du keine Schmerzen, die sie
   loesen.

Aufraeumen:

```bash
k3d cluster delete homelab
```

Die Werkzeuge in `~/.local/bin` bleiben und kosten nichts.

---

## WAS WIR NICHT MACHEN

Gestrichen ist nicht falsch, nur nicht 45-Minuten-tauglich. Alles davon steht in der Langfassung.

| Gestrichen | Warum | Wo es steht |
|---|---|---|
| **Nextcloud hands-on** | 461 MB + Postgres 112 MB pro Person, dazu Secret, DB, PVC und eine minutenlange Erstinstallation. Versteckt genau die Objekte, die wir lehren | Rahmenstory in Minute 0, Schritt 1 in "Wie geht es weiter" |
| **Der imperative/deklarative Umweg** (`kubectl get deploy -o yaml`, `--dry-run=client -o yaml`, `set image`, `rollout status`, `rollout undo`) | drei bis vier Minuten fuer eine Erkenntnis, die eine Datei besser vermittelt als ein Befehl | **Lies `manifests/20-whoami.yaml`** — das ist genau das Deployment, der Service und der Ingress aus dem Workshop als Datei, mit Kommentaren. Zuhause aenderst du dort den Tag und machst `kubectl apply`; `set image` ist der Feuerloescher, nicht der Arbeitsweg |
| **Orientierungs-Tour durch `kube-system`** | vier Minuten Sightseeing, in dem niemand etwas tut. Die drei Komponenten, die man wirklich kennen muss, stehen jetzt dort, wo sie gebraucht werden | coredns im Service-Teil, traefik im Ingress-Teil, local-path im Persistenz-Block — je ein Satz |
| **EndpointSlices und die Demo "Service ohne Endpoints"** | 2 min Vorfuehrung fuer eine Regel, die ein Satz genauso gut sagt | die Regel steht im Service-Teil: `Endpoints` leer → immer Selector oder Pod, nie das Netzwerk |
| **NodePort vs. LoadBalancer** | reine Lesestoff-Entscheidung, kostet live 4 Minuten Diskussion: `NodePort` vergibt einen Zufallsport ab 30000 und muss in k3d zusaetzlich durch den Docker-Wrapper gereicht werden (`k3d cluster edit --port-add`). `LoadBalancer` ist im echten Homelab die richtige Antwort (MetalLB gibt eine LAN-IP), in k3d bekommst du eine Docker-Netz-IP wie `172.20.0.3`, die nur von einem Linux-Host mit rootful Docker erreichbar ist — auf Docker Desktop und rootless Docker ist sie tot. Nebenwirkung: `--type=LoadBalancer --port=80` bleibt in k3d auf `EXTERNAL-IP: <pending>` stehen, weil Klipper pro Service ein DaemonSet mit `hostPort` anlegt und Port 80 schon Traefik haelt. **Ingress funktioniert in k3d und im Homelab identisch — deshalb nur Ingress** | [PLAN.md](./PLAN.md), Abschnitt Service |
| **`kubectl port-forward`** | braucht ein zweites Terminal pro Person; das kostet mehr Zeit als es lehrt. Merksatz genuegt: es ist ein Debug-Werkzeug, laeuft im Vordergrund und nur fuer dich. Wenn: immer `deploy/web` oder `svc/web` adressieren, nie `web-*` (die Shell expandiert das nicht gegen Kubernetes-Namen) | [PLAN.md](./PLAN.md), Abschnitt Deployment |
| **Interaktive Shell fuer alle** (`kubectl run tmp -it --rm`) | zwoelf Leute vergessen `exit` und landen bei `pods "tmp" already exists` | hier als Trainer-Demo in Minute 24–34 |
| **MariaDB per Helm + Go-App** | Multi-Container-Story mit DB-Verbindung ist ein eigener Termin | [PLAN.md](./PLAN.md), [examples/go-mariadb-demo](./examples/go-mariadb-demo/README.md) |
| **CloudNativePG, PG 17→18 Major Upgrade** | der Wow-Effekt setzt Postgres-Betriebserfahrung voraus; ohne die klingt es nach Magie und frisst den Ingress-Block | [examples/cnpg-major-upgrade-autopilot](./examples/cnpg-major-upgrade-autopilot/README.md) |
| **Operator Capability Levels** | interessiert niemanden, der einen Dienst betreiben will | [PLAN.md](./PLAN.md), Abschnitt CNPG |
| **Deployment vs. StatefulSet vs. DaemonSet** | ein Deployment reicht fuer 90 % der Homelab-Dienste | [PLAN.md](./PLAN.md) |
| **`api-resources` / `explain`-Tour** | Nachschlagewerk, kein Workshop-Inhalt. Einmal nennen: `kubectl explain deployment.spec` | [PLAN.md](./PLAN.md), Abschnitt 1 |
| **Headlamp, FreeLens** | 30 s k9s reicht, Tool-Auswahl ist Geschmack | [PLAN.md](./PLAN.md), Abschnitt UI Tools |
| **Namespaces, RBAC, NetworkPolicies, Probes im Detail, Resources/Limits** | alles richtig und wichtig, alles Tag 2. Im Manifest ist eine `readinessProbe` zu sehen — ein Satz dazu, fertig | [PLAN.md](./PLAN.md) |

---

## Kuerzungsplan

Der Ankerpunkt: **bei Minute 32 muessen die drei `curl`-Zeilen gelaufen sein**, damit der
Persistenz-Block ab Minute 34 die vollen acht Minuten hat. Bist du bei Minute 32 noch im
Deployment- oder Service-Teil, streiche in **genau dieser** Reihenfolge, bis du wieder im Plan
bist:

1. **k9s-Demo** (Deployment-Block) — 30 s, schmerzlos.
2. **Trainer-Demo Wegwerf-Pod** (Service-Teil) — 90 s. DNS dann behaupten statt zeigen; die drei
   `curl`-Zeilen beweisen es gleich ohnehin nochmal.
3. **`docker exec ... /var/lib/rancher/k3s/storage`** (Persistenz) — 20 s, dafuer den
   Longhorn-Satz sagen.
4. **`grep -n -A4 ... manifests/10-uptime-kuma.yaml`** (Persistenz) — statt vorfuehren den Satz
   sagen: PVC-Name, `volumeMount`, `volumes` muessen zusammenpassen, und die Datei liegt im Repo.
5. **`kubectl exec deploy/kuma -- ls -la /app/data`** (Persistenz) — der Beweis funktioniert auch
   ohne vorher hinzuschauen.
6. **Browser auf `kuma.k3d.localhost`** — letzter Ausweg, kostet die Anschaulichkeit. Die drei
   `curl`-Zeilen bleiben. (Das `kubectl wait` bleibt trotzdem: es kostet nichts und verhindert,
   dass der Persistenz-Block auf einen Pod trifft, der noch zieht.)

**Nicht streichen, unter keinen Umstaenden** — das sind die vier Momente, fuer die die Leute
gekommen sind:

- `kubectl delete pod -l app=web` → Pod kommt mit neuem Namen zurueck (Deployment, 16–24)
- `kubectl describe svc web` → `Selector` und `Endpoints` (Service/Ingress, 24–34)
- drei `curl` mit unterschiedlichem `Host`-Header auf **dieselbe** Adresse (Service/Ingress, 24–34)
- `kubectl delete pod -l app=kuma` → `beweis.txt` ist noch da (Persistenz, 34–42)

Wenn bei Minute 30 klar ist, dass es nicht fuer beides reicht: die drei `curl`-Zeilen machen,
den Browser-Blick streichen und direkt in die Persistenz gehen. Persistenz ueberzeugt mehr Leute
als Routing, und Kuma laeuft zu diesem Zeitpunkt sowieso schon.

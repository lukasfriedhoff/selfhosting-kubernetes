# Workshop 45 min: Selfhosting with Kubernetes

Trainer script for a 45-minute session with about 12 participants.
Long version (2 h, with Helm, MariaDB and CloudNativePG): [PLAN.md](./PLAN.md).

Target audience: knows Docker and a terminal, wants to run services at home, reach them on the
LAN and not lose any data. No CKA, no operator capability levels.

---

## Minute budget

| min | Block | Who types |
|---:|---|---|
| 0–2 | [Framing: Nextcloud is the goal](#02-min--framing-nextcloud-is-the-goal) | nobody |
| 2–16 | [Setup together: tools, cluster, start Uptime Kuma right away](#216-min--setup-together) | everyone |
| 16–24 | [Deployment: the pod is disposable](#1624-min--deployment-the-pod-is-disposable) | everyone |
| 24–34 | [Service and Ingress: one address, two services](#2434-min--service-and-ingress-one-address-two-services) | everyone + 1 trainer demo |
| 34–42 | [Persistence: the pod dies, the data does not](#3442-min--persistence-the-pod-dies-the-data-does-not) | everyone |
| 42–45 | [Where to go next + Q&A](#4245-min--where-to-go-next) | nobody |

Total: 2 + 14 + 8 + 10 + 8 + 3 = **45**. Questions get answered **inside the block**, not
collected — that is why the wrap-up is short.

Rule of thumb for the trainer: **two sentences per term, then move on.** Every block ends with a
*Symptom → Cause → Fix* table. If a message is not in it, it is a Q&A after the session, not live
debugging.

---

## Prerequisites

**A running Docker engine that your own user is allowed to use.** Docker Desktop counts.
That is all.

Tools get installed during the session: `scripts/setup-tools.sh` drops `kubectl`, `helm`,
`k3d` and `k9s` as binaries into `~/.local/bin` and sets up completions for bash and zsh.
No root, no package manager, no snap.

---

## 0–2 min — Framing: Nextcloud is the goal

**Trainer talks, nobody types.**

> The goal most people here are sitting with is **Nextcloud on your own network**: your own files,
> your own calendar, your own address with HTTPS. We are deliberately *not* installing it today —
> `nextcloud:31-apache` is 461 MB, plus a Postgres database at 112 MB, a Secret, a PVC and a
> first-run install that takes minutes. That eats the session and hides exactly the objects this
> is about. Nextcloud is made of four building blocks, and today we build those on a service that
> starts in seconds. At the end Nextcloud is step 1 on your list — and then you can read every
> line of it.

Why not `docker compose`? There is exactly one thing Compose cannot do: restore the state you
asked for. Kubernetes is a control loop — you describe the desired state, the cluster holds it.

Vocabulary, 30 seconds, no more:

| Object | In one sentence |
|---|---|
| **Pod** | one or more containers, short-lived, replaceable |
| **Deployment** | "keep n pods of this image alive" |
| **Service** | stable name and stable IP in front of changing pods |
| **Ingress** | HTTP router from outside to inside, by hostname |
| **PVC** | requested storage, outlives the pod |

By the end of the session two services run under two hostnames on **one** port, and one of them
has data that survives the death of a pod.

---

## 2–16 min — Setup together

**Everyone types.** Goal: everyone has a cluster, and the 149 MB download is running in the
background before we start explaining.

**The budget is 14 minutes, and it is tight, not generous:** 2–3 min tools,
**1–4 min cluster**, ~1 min Kuma and a look at it, the rest is slack for the two or three
people whose Docker refuses. If you need 16 minutes here, cut later per the
[cut list](#cut-list) — that is planned for, not failure.

```bash
git clone https://github.com/lukasfriedhoff/selfhosting-kubernetes.git
cd selfhosting-kubernetes
./scripts/setup-tools.sh
```

Without `git`:

```bash
curl -fsSL https://github.com/lukasfriedhoff/selfhosting-kubernetes/archive/HEAD.tar.gz | tar xz
cd selfhosting-kubernetes-*
```

The run takes 2–3 minutes (four downloads, ~135 MB, with checksum verification). Then reload the
shell and check for yourself:

```bash
source ~/.bashrc      # zsh: source ~/.zshrc - or just open a new tab
./scripts/setup-tools.sh --check
```

**Expect to see:** five green `ok` lines (`docker`, `kubectl`, `helm`, `k3d`, `k9s`) and
`ok docker is running and usable`. Exit code 0.

### A name for the host port: `WS_PORT`

Everything that later goes into the cluster from outside uses **this one variable**. Set it once,
now, all together — then there is no search-and-replace for the rest of the session:

```bash
export WS_PORT=8080
```

**If 8080 is taken on your machine** (common: Jenkins, Tomcat, another Docker project), then
**now** `export WS_PORT=18080` — or 28080, does not matter — and carry on like everyone else.
From here on every command says `$WS_PORT` and never a number again. Two things about that:

- The variable lives in **this** shell. New tab? `export WS_PORT=...` again, or just
  `echo 'export WS_PORT=8080' >> ~/.bashrc`.
- The **browser** does not do variables. When we type a URL later, `echo $WS_PORT` gives you the
  number that belongs there.

### Cluster

Now the cluster — one line, deliberately without line breaks:

```bash
k3d cluster create homelab --image rancher/k3s:v1.36.4-k3s1 -p "${WS_PORT}:80@loadbalancer"
```

**This takes 1–4 minutes, not 20 seconds.** The command first pulls the k3s node image
(`rancher/k3s`, ~95 MB together with the k3d proxy) and only then starts the cluster. The
"17–40 seconds" you read in blog posts and in my own test runs are for a **warm Docker cache** —
nobody here has one. Twelve people, one wifi: four minutes is normal.

**Expect to see:** last line `Cluster 'homelab' created successfully!`.

```bash
kubectl get nodes
```

**Expect to see:** one line, `Ready`, `control-plane`, version `v1.36.4+k3s1`.

### And start Uptime Kuma right away

No pause, the most important command of the setup:

```bash
kubectl apply -f manifests/10-uptime-kuma.yaml
kubectl get pvc
```

**Expect to see:** four `created` lines — and for the PVC:

```
NAME        STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
kuma-data   Pending                                      local-path     <unset>                 1s
```

`Pending` is **correct**, not broken: `local-path` uses
`volumeBindingMode: WaitForFirstConsumer`, the volume is only created once it is clear which node
the pod runs on. In ten seconds it will say `Bound`.

**The trainer now says the sentence that buys the next eighteen minutes:**
"From here on a 149 MB image is downloading in the background. That is on purpose. We keep
talking, and when we come back in minute 32, it is there."

### Symptom → Cause → Fix

| Symptom | Cause | Fix |
|---|---|---|
| `permission denied ... /var/run/docker.sock` | user not in the `docker` group | `sudo usermod -aG docker "$USER"`, **log out and log back in**. Live: sit next to someone, do not debug |
| `k3d: command not found` after the setup | shell not reloaded | `source ~/.bashrc` or a new tab |
| `port is already allocated` on `cluster create` | host port taken | `export WS_PORT=18080`, then `cluster create` again. Only this one spot, everything else uses `$WS_PORT` |
| later `connection refused` on `127.0.0.1:$WS_PORT` | `WS_PORT` not set in a new tab (so it is empty) | `echo $WS_PORT` — empty? `export WS_PORT=...` with the value the cluster was created with. Worst case, `docker ps \| grep serverlb` shows the number |
| `cluster create` hangs for minutes at `Starting new tools node` | exactly the image pull described above | expected, keep talking. `docker pull rancher/k3s:v1.36.4-k3s1` in a second tab shows the progress |
| cluster already exists (`failed to create cluster`) | leftovers from an earlier attempt | `k3d cluster delete homelab` and start over |
| `kubectl get nodes` shows `v1.21.x` | k3d **<= 5.8.3** falls back to a hardcoded k3s version from 2021 when the lookup on `update.k3s.io` fails (conference wifi!) | that is exactly why k3d v5.9.0 (via the setup script) **and** `--image rancher/k3s:v1.36.4-k3s1` are pinned. With the `--image` flag it cannot happen |
| `kubectl apply` says `no such file or directory` | wrong directory | `cd` into the cloned repo; `ls manifests/` must show two `.yaml` files |
| `error: You must be logged in to the server` | kubeconfig points at a different cluster | `kubectl config use-context k3d-homelab` |

---

## 16–24 min — Deployment: the pod is disposable

**Goal in one sentence:** show that a deleted pod comes back on its own — the one difference from
`docker run` that everything hangs on.

**Everyone types.**

```bash
kubectl create deployment web --image traefik/whoami:v1.12.0
kubectl get pods -l app=web
```

`traefik/whoami` is 5 MB and starts instantly — that is why this, and not Kuma, is the service to
play with. The tag is pinned: with `:latest` Kubernetes sets `imagePullPolicy: Always` and pulls
again on every start.

And now the moment people came for:

```bash
kubectl delete pod -l app=web
kubectl get pods -l app=web
```

**Expect to see:** `pod "web-85875947cf-4nldt" deleted from default namespace`, and right after it
a pod with a **new name**
and `AGE 1s`. About one second passes between the two commands.

> **This is the difference from `docker run`.** You did not lose the pod, you got it replaced.
> What you deleted was one instance of a wish, not the wish itself. The wish is called
> Deployment.

Diagnostic tooling, in this order — these are the commands that answer 90 % of all questions at
home:

```bash
kubectl logs deploy/web
kubectl describe deploy/web
```

**Expect to see:** for `logs` one line `Starting up on port 80`; for `describe` at the very bottom
`Events:` with `ScalingReplicaSet`. **Always read the events first, not the logs.**

> **The trap everybody hits: `exec` needs a shell in the image.**
> `kubectl exec -it deploy/web -- sh` fails with
> `exec: "sh": executable file not found in $PATH`. `traefik/whoami` is 5 MB and has no shell
> — like almost all modern images (distroless). The way out is a throwaway pod, and the trainer
> shows that in a moment.

**Trainer demo, 30 seconds, nothing else:** start `k9s`, type `:pods`, `l` for logs,
`d` for describe, `Esc`, then `:q`. No learning objective — just so everyone knows it exists and
that `describe` and `logs` are two keystrokes in it. This is the first item on the
[cut list](#cut-list).

### Symptom → Cause → Fix

| Symptom | Cause | Fix |
|---|---|---|
| `ImagePullBackOff` on `web` | typo in the image or no network | `kubectl describe pod -l app=web \| tail -5`. Emergency exit: `kubectl delete deploy web` and `kubectl apply -f manifests/20-whoami.yaml` |
| `kubectl get pods` shows **two** `web` pods after the delete | the old one is still terminating | wait a second, look again. That is exactly why it says `-l app=web` here and not a pod name |
| `error: name cannot be provided when a selector is specified` | `-l` and a pod name mixed | one or the other, never both |
| `deployments.apps "web" already exists` | block already ran once | `kubectl delete deploy web`, or just carry on |

---

## 24–34 min — Service and Ingress: one address, two services

**Goal in one sentence:** a Service is a DNS name plus a list of endpoints, an Ingress is a router
in front of it — and at the end two services run on **one** port, told apart by nothing but the
hostname. That is the homelab moment.

Ten minutes, two halves, no pause for breath in between.

### Part 1: the Service — a name instead of an IP

**Everyone types:**

```bash
kubectl expose deployment web --port 80
kubectl describe svc web
```

**Expect to see** — exactly two lines matter:

```
Selector:                 app=web
Endpoints:                10.42.0.12:80
```

`Selector` says which pods are meant. `Endpoints` says which ones actually exist.

> **The homelab rule, said once and never demoed:** service unreachable →
> `kubectl describe svc <name>` → if `Endpoints` is **empty**, it is *always* the selector or a
> pod that is not running. **Never** the network. (The most common source of that:
> `kubectl create service` derives the selector from the **service name**, `kubectl expose` from
> the **workload**.)

That `http://web` and `http://kuma` work as addresses comes from **coredns** — the
cluster-internal DNS that has been running in `kube-system` since minute 2, without us
installing it.

#### Trainer demo: the throwaway pod (projector, NOT everyone)

**Deliberately the trainer only.** Twelve people in an interactive shell means: twelve people
forget `exit`, and the second attempt gets `pods "tmp" already exists`.

```bash
kubectl run tmp -it --rm --image alpine:3 -- sh
```

Inside the pod:

```sh
getent hosts web
wget -qO- http://web
wget -qO- http://kuma
exit
```

**Expect to see:** `getent` returns `10.43.104.214 web.default.svc.cluster.local ... web` — the
name exists cluster-internally. `wget http://web` returns the whoami dump including
`Hostname: web-...`. And `http://kuma` answers with `302 Found, Location: /dashboard` —
so the image finished downloading without us ever looking at it. If nothing comes back here, Kuma
is still pulling; there is an explicit `kubectl wait` for that further down.

Takeaway: a Service is a **DNS name plus a list of endpoints**. Nothing more.

> Side note in case someone types the full name: `wget http://web.default.svc.cluster.local`
> fails in Alpine with `bad address`, `wget http://web.default.svc.cluster.local.` (trailing
> dot!) works. The reason is `ndots:5` in `/etc/resolv.conf` plus musl, which unlike glibc does
> not fall back to the absolute name. Use short names, topic closed.

### Part 2: the Ingress — two services, one address

k3s ships the reverse proxy itself: **traefik** runs in `kube-system` as the ingress controller
and sits on port 80 of the node — which is exactly where our mapped host port `$WS_PORT` comes
out.

Uptime Kuma already has its Ingress from `manifests/10-uptime-kuma.yaml`. Only the one for `web`
is missing:

```bash
kubectl create ingress web --class=traefik --rule="whoami.k3d.localhost/*=web:80"
kubectl get ingress
```

**Expect to see:** two lines, both with `CLASS traefik` and, after 5–15 seconds, an IP in
`ADDRESS` (in k3d something like `172.20.0.2`).

```bash
curl -H 'Host: whoami.k3d.localhost' http://127.0.0.1:$WS_PORT
curl -s -o /dev/null -w 'kuma: HTTP %{http_code}\n' -H 'Host: kuma.k3d.localhost' http://127.0.0.1:$WS_PORT
curl -s -o /dev/null -w 'no Host: HTTP %{http_code}\n' http://127.0.0.1:$WS_PORT
```

**Expect to see:**

- the whoami dump with `Host: whoami.k3d.localhost` and Traefik's `X-Forwarded-*` headers,
- `kuma: HTTP 302` — Kuma redirects to `/dashboard`, that is the right answer, not 200,
- `no Host: HTTP 404` — Traefik answers, but without a hostname it knows no route.

**These three lines are the whole block.** Same IP, same port, three different results, and the
only difference is the `Host` header. That is exactly host-based routing; everything else is DNS
cosmetics.

### Before anyone opens a browser: wait once

**Everyone types — this step is not skipped:**

```bash
kubectl wait --for=condition=Ready pod -l app=kuma --timeout=300s
```

**Expect to see:** `pod/kuma-... condition met`. Only after that does anyone open a browser —
otherwise three people see an error and we debug a download. The 300 seconds are deliberately
generous: twelve simultaneous pulls of 149 MB through conference wifi take time. If you hit the
timeout here you have a network problem, not a Kubernetes problem —
`kubectl describe pod -l app=kuma | tail -5` then shows `Pulling`.

Now the look that makes it believable — **in the browser**, with the port number from
`echo $WS_PORT`:

```
http://kuma.k3d.localhost:8080
```

(If you changed `WS_PORT` above, type the number from `echo $WS_PORT` here instead of 8080 —
that is the only place in the whole session where the number has to go in by hand.)

**Expect to see:** the Uptime Kuma setup screen. A real homelab service, behind a hostname, out of
four YAML objects. **Do not set anything up yet** — that comes in the next block.

**This is what it looks like at home** (one sentence, do not demo): a wildcard DNS record
`*.home.example.com` points at Traefik's LoadBalancer IP, cert-manager fetches the certificate,
and from then on every new service is exactly this one `Ingress` line. That is the real win over
Compose plus a hand-maintained reverse proxy.

### Symptom → Cause → Fix

| Symptom | Cause | Fix |
|---|---|---|
| `services "web" already exists` | `expose` ran twice — **or** someone used the emergency exit `kubectl apply -f manifests/20-whoami.yaml` in minute 16–24, which creates the Service and the Ingress along with it | `kubectl delete svc web`, then again — or just carry on, the Service is already there |
| `Endpoints` empty although the pod is running | label does not match the selector | compare `kubectl get pods --show-labels` with `kubectl describe svc` |
| `pods "tmp" already exists` | someone typed along during the trainer demo and forgot `exit` | `kubectl delete pod tmp --now` |
| `ADDRESS` stays empty | IngressClass does not take | `kubectl get ingressclass`; if `traefik` is not the default, `--class=traefik` is exactly the fix (already in the command above) |
| no `traefik` pod in `kube-system` | cluster not finished yet (k3s installs Traefik via a Job; `helm-install-traefik-*` on `Completed` is healthy) | wait 20 s, then `kubectl get pods -n kube-system` again |
| `HTTP 404` **with** a correct Host header | Ingress points at a Service that has no endpoints | back to `kubectl describe svc web` |
| `HTTP 503` | Service is there, pod is not ready (yet) | `kubectl get pods`; with Kuma just wait |
| `HTTP 000` / `connection refused` | host port not forwarded or `$WS_PORT` empty | check `echo $WS_PORT`; `docker ps \| grep serverlb` must show `0.0.0.0:<WS_PORT>->80/tcp`. Otherwise recreate the cluster with `-p` |
| browser: `kuma.k3d.localhost` does not resolve | glibc has no special rule for `*.localhost`; it works with `systemd-resolved`, often not with dnsmasq | `echo '127.0.0.1 whoami.k3d.localhost kuma.k3d.localhost' \| sudo tee -a /etc/hosts`. That is why the `curl -H` variant comes **first**: it needs no DNS at all |
| browser ends up on `https://` or in the search engine, curl works | browser forces an HTTPS upgrade or reads the name as a search term | type `http://` explicitly and hit Enter instead of picking a suggestion; when in doubt the `curl` lines stand, they prove the same thing |

---

## 34–42 min — Persistence: the pod dies, the data does not

**Goal in one sentence:** prove that a PVC outlives the pod — on a service that has a real
database file.

First look at what is actually in there:

```bash
kubectl get pvc
kubectl exec deploy/kuma -- ls -la /app/data
```

**Expect to see:** PVC on `Bound`, `RWO`, `1Gi`, StorageClass `local-path` — and in the directory
`kuma.db`, `kuma.db-shm`, `kuma.db-wal`. That is SQLite. One service, one file, one PVC:
the most common case in a homelab.

Where the StorageClass comes from without us creating it: **local-path-provisioner**, also built
into k3s and the default `StorageClass` — it turns a PVC into a directory on exactly this one
node.

Now set the marker and kill the pod:

```bash
kubectl exec deploy/kuma -- sh -c 'echo "workshop 2026" > /app/data/proof.txt'
kubectl delete pod -l app=kuma
kubectl wait --for=condition=Ready pod -l app=kuma --timeout=120s
kubectl exec deploy/kuma -- cat /app/data/proof.txt
```

**Expect to see:** `kubectl delete` blocks for ~5 seconds (it waits until the pod is really gone),
`kubectl wait` reports `condition met` after another ~7 seconds, and `cat` prints
`workshop 2026`. **New pod, old file.**

> **Why exactly these four lines, and not `rollout status`:** `kubectl rollout status` can report
> success while the old pod is still terminating — then the following
> `kubectl exec deploy/kuma` grabs the dying pod and fails with
> `unable to upgrade connection`. `kubectl delete`, by contrast, **blocks** by default until the
> object is gone, and `kubectl wait --for=condition=Ready` waits for the successor. Together
> that is race-free.
>
> Also do **not** use: `kubectl wait --for=delete pod -l app=kuma`. On start it grabs a list of
> all matching pods — and the replacement pod carries the same label. The command then waits
> until the timeout for the deletion of a pod that has just started, and ends with
> `timed out waiting for the condition`. A race you lose often: two out of three runs failed in
> testing here. If you really want to wait for the deletion, wait on a **name**:
> ```bash
> POD=$(kubectl get pod -l app=kuma -o name)
> kubectl delete "$POD" --wait=false
> kubectl wait --for=delete "$POD" --timeout=60s
> kubectl wait --for=condition=Ready pod -l app=kuma --timeout=120s
> ```

**Trainer demo, 20 seconds:** where the data actually lives.

```bash
docker exec k3d-homelab-server-0 ls /var/lib/rancher/k3s/storage
```

A directory on **one** node. That says the most important homelab consequence:
`local-path` means the data is glued to this one machine. As soon as you have a second node, the
pod starts there and finds an empty directory — from then on you need Longhorn, NFS or Ceph. And
`local-path` makes no backups.

A look at the file that describes all of it — three blocks, no more:

```bash
grep -n -A4 -E 'kind: PersistentVolumeClaim|volumeMounts:|persistentVolumeClaim:' manifests/10-uptime-kuma.yaml
```

Three spots have to match, and that is the whole art: the PVC has a **name**, the container has a
`volumeMount` with a `mountPath`, and the `volumes` field connects the two.

### Symptom → Cause → Fix

| Symptom | Cause | Fix |
|---|---|---|
| `unable to upgrade connection` on `exec` | pod not ready yet or just gone | `kubectl wait --for=condition=Ready pod -l app=kuma --timeout=120s`, then again |
| `kubectl wait`: `no matching resources found` | too soon after the delete, replacement pod not created yet | just run the command again |
| PVC hangs on `Terminating` during cleanup | finalizer `kubernetes.io/pvc-protection`, as long as a pod is using it | protection, not a bug: `kubectl delete deploy kuma` first, then `kubectl delete pvc kuma-data` |
| Kuma pod stays `0/1 Running` | readinessProbe still in its grace period (up to 70 s on the first start) | wait. `kubectl describe pod -l app=kuma \| tail -5` shows whether it is the probe |
| `Multi-Attach error` / new pod does not mount | two pods want one RWO volume | that is exactly why `strategy: type: Recreate` is in the manifest. Change it to RollingUpdate and you build this in yourself |

---

## 42–45 min — Where to go next

**Nobody types.** Name two terms so they are not strangers:

- **Helm** is finished YAML from other people, parameterized. The only thing that matters is the
  realization: Helm produces **exactly the objects we built today**.
  `helm get manifest <name>` shows them, and `kubectl describe` is how you fix them yourself.
  Directory: [artifacthub.io](https://artifacthub.io).
- **Operators** go one step further: a controller that *operates* a service instead of just
  installing it — for databases, **CloudNativePG** takes over failover, backups and major
  upgrades. That is day 2, see [PLAN.md](./PLAN.md).

The realistic path home, in this order:

1. **Nextcloud** — the goal from minute 0. You need exactly the four objects from today for it,
   plus two new terms: a **Secret** for the database password and a second Deployment for
   **Postgres**. Realistically one evening, and you can read every line at the end. Starting
   point: the official chart via [artifacthub.io](https://artifacthub.io), then **make sure** you
   read `helm get manifest nextcloud` — that is where you find the PVC, Service and Ingress again.
2. **The same service again by hand**, without a chart. From here on you decipher other people's
   charts instead of trusting them. Starting point is `manifests/20-whoami.yaml` from this repo:
   the same objects we typed, as a file.
3. **Out of k3d**, onto real hardware: k3s on a machine or a VM. Now you need real DNS (wildcard
   to the cluster IP), **MetalLB** for LAN IPs and **cert-manager** for certificates.
4. **Second node** — and here the storage question from minute 34 comes back. `local-path` does
   not carry that any more: Longhorn, or NFS if there is a NAS.
5. **Only then** GitOps (Flux/Argo) and operators. Before that you have no pain for them to
   solve.

Cleanup:

```bash
k3d cluster delete homelab
```

The tools in `~/.local/bin` stay and cost nothing.

---

## WHAT WE ARE NOT DOING

Cut is not wrong, just not fit for 45 minutes. All of it is in the long version.

| Cut | Why | Where it lives |
|---|---|---|
| **Nextcloud hands-on** | 461 MB + Postgres 112 MB per person, plus a Secret, a DB, a PVC and a first-run install that takes minutes. Hides exactly the objects we are teaching | framing story in minute 0, step 1 in "Where to go next" |
| **The imperative/declarative detour** (`kubectl get deploy -o yaml`, `--dry-run=client -o yaml`, `set image`, `rollout status`, `rollout undo`) | three to four minutes for an insight a file conveys better than a command | **Read `manifests/20-whoami.yaml`** — that is exactly the Deployment, the Service and the Ingress from the workshop as a file, with comments. At home you change the tag in there and run `kubectl apply`; `set image` is the fire extinguisher, not the way you work |
| **Orientation tour through `kube-system`** | four minutes of sightseeing in which nobody does anything. The three components you really have to know are now where they are needed | coredns in the Service part, traefik in the Ingress part, local-path in the persistence block — one sentence each |
| **EndpointSlices and the "Service without endpoints" demo** | 2 min of live demo for a rule one sentence says just as well | the rule is in the Service part: `Endpoints` empty → always the selector or the pod, never the network |
| **NodePort vs. LoadBalancer** | pure reading material, costs 4 minutes of live discussion: `NodePort` hands out a random port from 30000 up and in k3d additionally has to be routed through the Docker wrapper (`k3d cluster edit --port-add`). `LoadBalancer` is the right answer in a real homelab (MetalLB gives you a LAN IP), in k3d you get a Docker-network IP like `172.20.0.3` that only a Linux host with rootful Docker can reach — on Docker Desktop and rootless Docker it is dead. Side effect: `--type=LoadBalancer --port=80` stays on `EXTERNAL-IP: <pending>` in k3d, because Klipper creates one DaemonSet with `hostPort` per Service and Traefik already holds port 80. **Ingress works identically in k3d and in a homelab — that is why Ingress only** | [PLAN.md](./PLAN.md), Service section |
| **`kubectl port-forward`** | needs a second terminal per person; that costs more time than it teaches. The takeaway is enough: it is a debug tool, runs in the foreground and only for you. If you do use it: always address `deploy/web` or `svc/web`, never `web-*` (the shell does not expand that against Kubernetes names) | [PLAN.md](./PLAN.md), Deployment section |
| **Interactive shell for everyone** (`kubectl run tmp -it --rm`) | twelve people forget `exit` and end up at `pods "tmp" already exists` | here as a trainer demo in minute 24–34 |
| **MariaDB via Helm + Go app** | a multi-container story with a DB connection is its own session | [PLAN.md](./PLAN.md), [examples/go-mariadb-demo](./examples/go-mariadb-demo/README.md) |
| **CloudNativePG, PG 17→18 major upgrade** | the wow effect assumes Postgres operations experience; without it, it sounds like magic and eats the Ingress block | [examples/cnpg-major-upgrade-autopilot](./examples/cnpg-major-upgrade-autopilot/README.md) |
| **Operator capability levels** | nobody who wants to run a service cares | [PLAN.md](./PLAN.md), CNPG section |
| **Deployment vs. StatefulSet vs. DaemonSet** | a Deployment is enough for 90 % of homelab services | [PLAN.md](./PLAN.md) |
| **`api-resources` / `explain` tour** | reference material, not workshop content. Name it once: `kubectl explain deployment.spec` | [PLAN.md](./PLAN.md), section 1 |
| **Headlamp, FreeLens** | 30 s of k9s is enough, tool choice is taste | [PLAN.md](./PLAN.md), UI Tools section |
| **Namespaces, RBAC, NetworkPolicies, probes in detail, resources/limits** | all correct and all important, all day 2. There is a `readinessProbe` to see in the manifest — one sentence about it, done | [PLAN.md](./PLAN.md) |

---

## Cut list

The anchor point: **by minute 32 the three `curl` lines must have run**, so the persistence block
gets its full eight minutes from minute 34. If you are still in the Deployment or Service part at
minute 32, cut in **exactly this** order until you are back on plan:

1. **k9s demo** (Deployment block) — 30 s, painless.
2. **Trainer demo throwaway pod** (Service part) — 90 s. Then claim DNS instead of showing it; the
   three `curl` lines prove it again in a moment anyway.
3. **`docker exec ... /var/lib/rancher/k3s/storage`** (persistence) — 20 s, say the Longhorn
   sentence instead.
4. **`grep -n -A4 ... manifests/10-uptime-kuma.yaml`** (persistence) — instead of demoing it, say
   the sentence: PVC name, `volumeMount`, `volumes` have to match, and the file is in the repo.
5. **`kubectl exec deploy/kuma -- ls -la /app/data`** (persistence) — the proof works without
   looking first.
6. **Browser on `kuma.k3d.localhost`** — last resort, costs you the vividness. The three
   `curl` lines stay. (The `kubectl wait` stays regardless: it costs nothing and keeps the
   persistence block from hitting a pod that is still pulling.)

**Do not cut, under any circumstances** — these are the four moments people came for:

- `kubectl delete pod -l app=web` → pod comes back with a new name (Deployment, 16–24)
- `kubectl describe svc web` → `Selector` and `Endpoints` (Service/Ingress, 24–34)
- three `curl`s with a different `Host` header against **the same** address (Service/Ingress, 24–34)
- `kubectl delete pod -l app=kuma` → `proof.txt` is still there (persistence, 34–42)

If at minute 30 it is clear there is not enough time for both: do the three `curl` lines, cut the
browser look and go straight into persistence. Persistence convinces more people than routing,
and Kuma is already running by that point anyway.

# manifests/

YAML fuer die 45-Minuten-Session ([WORKSHOP-45MIN.md](../WORKSHOP-45MIN.md)).

Absichtlich Dateien und keine Heredocs zum Kopieren: automatisches Einruecken
und "bracketed paste" verstuemmeln ein 40-zeiliges YAML im Terminal
zuverlaessig, und in einer Live-Session ist das der teuerste Fehler.

| Datei | Inhalt | Wann |
|---|---|---|
| `10-uptime-kuma.yaml` | PVC + Deployment + Service + Ingress fuer Uptime Kuma | direkt nach `k3d cluster create` - das Image ist 149 MB und soll im Hintergrund ziehen |
| `20-whoami.yaml` | Deployment + Service + Ingress fuer `traefik/whoami` | Notausgang und Lesestoff; im Workshop wird das imperativ getippt |

```bash
kubectl apply -f manifests/10-uptime-kuma.yaml
kubectl apply -f manifests/20-whoami.yaml     # optional
```

Aufraeumen:

```bash
kubectl delete -f manifests/20-whoami.yaml --ignore-not-found
kubectl delete -f manifests/10-uptime-kuma.yaml --ignore-not-found
# oder gleich der ganze Cluster:
k3d cluster delete homelab
```

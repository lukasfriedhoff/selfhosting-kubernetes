#!/usr/bin/env bash
# Workshop-Setup: laedt kubectl, helm, k3d und k9s als Binaries nach
# ~/.local/bin und richtet Shell-Completions fuer bash und zsh ein.
#
# Kein root, kein Paketmanager, kein snap: ein Verzeichnis, vier Binaries,
# ueberall gleich. Laeuft auf Linux und macOS, amd64 und arm64.
#
# Mehrfaches Ausfuehren ist ungefaehrlich (idempotent).
#
#   ./scripts/setup-tools.sh              # installieren
#   ./scripts/setup-tools.sh --check      # nur pruefen, nichts aendern
#   ./scripts/setup-tools.sh --latest     # neueste Versionen statt der gepinnten
#
# Die Versionen sind absichtlich gepinnt: bei einem Workshop mit 12 Leuten
# willst du, dass alle dasselbe haben, und nicht mitten in der Session
# feststellen, dass heute morgen ein Major-Release erschienen ist.

set -euo pipefail

KUBECTL_VERSION="${KUBECTL_VERSION:-v1.37.1}"
HELM_VERSION="${HELM_VERSION:-v4.3.0}"
K3D_VERSION="${K3D_VERSION:-v5.9.0}"
K9S_VERSION="${K9S_VERSION:-v0.51.0}"

PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
BASH_COMP_DIR="$PREFIX/share/bash-completion/completions"
ZSH_COMP_DIR="$PREFIX/share/zsh/site-functions"
MARKER="# >>> selfhosting-kubernetes workshop >>>"
MARKER_END="# <<< selfhosting-kubernetes workshop <<<"

CHECK_ONLY=0
USE_LATEST=0

c_ok=$'\033[1;32m'
c_warn=$'\033[1;33m'
c_err=$'\033[1;31m'
c_info=$'\033[1;34m'
c_off=$'\033[0m'

log() { printf '%s==>%s %s\n' "$c_info" "$c_off" "$*"; }
ok() { printf '  %sok%s   %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '  %swarn%s %s\n' "$c_warn" "$c_off" "$*" >&2; }
die() {
  printf '%serror:%s %s\n' "$c_err" "$c_off" "$*" >&2
  exit 1
}

usage() {
  sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      shift
      ;;
    --latest)
      USE_LATEST=1
      shift
      ;;
    -h | --help) usage ;;
    *) die "unbekannte Option: $1 (--help)" ;;
  esac
done

for c in curl tar uname install grep sed; do
  command -v "$c" >/dev/null || die "'$c' fehlt - bitte nachinstallieren"
done
if command -v sha256sum >/dev/null; then
  SHA_CMD="sha256sum"
elif command -v shasum >/dev/null; then
  SHA_CMD="shasum -a 256"
else
  die "weder sha256sum noch shasum gefunden"
fi

# --- Plattform ----------------------------------------------------------------
# k9s schreibt das OS gross (k9s_Linux_amd64.tar.gz), alle anderen klein. Genau
# solche Kleinigkeiten kosten sonst zehn Minuten Fehlersuche.
case "$(uname -s)" in
  Linux)
    OS="linux"
    OS_TITLE="Linux"
    ;;
  Darwin)
    OS="darwin"
    OS_TITLE="Darwin"
    ;;
  *) die "nicht unterstuetztes Betriebssystem: $(uname -s)" ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
  *) die "nicht unterstuetzte Architektur: $(uname -m) (nur amd64/arm64)" ;;
esac

if [[ "$USE_LATEST" -eq 1 ]]; then
  log "neueste Versionen ermitteln"
  gh_latest() {
    curl -fsSL --max-time 20 "https://api.github.com/repos/$1/releases/latest" \
      | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1
  }
  KUBECTL_VERSION="$(curl -fsSL --max-time 20 https://dl.k8s.io/release/stable.txt)"
  HELM_VERSION="$(gh_latest helm/helm)"
  K3D_VERSION="$(gh_latest k3d-io/k3d)"
  K9S_VERSION="$(gh_latest derailed/k9s)"
fi

log "Plattform: $OS/$ARCH   Ziel: $BIN_DIR"
printf '  kubectl %s | helm %s | k3d %s | k9s %s\n' \
  "$KUBECTL_VERSION" "$HELM_VERSION" "$K3D_VERSION" "$K9S_VERSION"

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  log "Pruefen (es wird nichts geaendert)"
  rc=0
  for t in docker kubectl helm k3d k9s; do
    if command -v "$t" >/dev/null; then
      ok "$t -> $(command -v "$t")"
    else
      warn "$t fehlt"
      [[ "$t" == docker ]] && rc=1
    fi
  done
  if command -v docker >/dev/null; then
    if docker info >/dev/null 2>&1; then
      ok "docker laeuft und ist nutzbar"
    else
      warn "docker antwortet nicht - laeuft der Daemon, und bist du in der Gruppe 'docker'?"
      rc=1
    fi
  fi
  exit "$rc"
fi

command -v docker >/dev/null \
  || warn "docker nicht gefunden - k3d braucht eine laufende Container-Runtime"

mkdir -p "$BIN_DIR" "$BASH_COMP_DIR" "$ZSH_COMP_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Laedt $1 nach $2 und prueft gegen die erwartete Summe $3.
fetch_verify() {
  local url="$1" out="$2" want="$3" got
  curl -fsSL --retry 3 --retry-delay 2 --max-time 300 -o "$out" "$url" \
    || die "Download fehlgeschlagen: $url"
  got="$($SHA_CMD "$out" | awk '{print $1}')"
  [[ "$got" == "$want" ]] \
    || die "Checksumme falsch fuer $(basename "$out")
  erwartet: $want
  bekommen: $got"
}

# --- kubectl ------------------------------------------------------------------
log "kubectl $KUBECTL_VERSION"
kube_base="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}"
want="$(curl -fsSL --max-time 60 "${kube_base}/kubectl.sha256")"
fetch_verify "${kube_base}/kubectl" "$TMP/kubectl" "$want"
install -m 0755 "$TMP/kubectl" "$BIN_DIR/kubectl"
ok "$BIN_DIR/kubectl"

# --- helm ---------------------------------------------------------------------
log "helm $HELM_VERSION"
helm_tgz="helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
want="$(curl -fsSL --max-time 60 "https://get.helm.sh/${helm_tgz}.sha256sum" | awk '{print $1}')"
fetch_verify "https://get.helm.sh/${helm_tgz}" "$TMP/$helm_tgz" "$want"
tar -xzf "$TMP/$helm_tgz" -C "$TMP"
install -m 0755 "$TMP/${OS}-${ARCH}/helm" "$BIN_DIR/helm"
ok "$BIN_DIR/helm"

# --- k3d ----------------------------------------------------------------------
# k3d veroeffentlicht keine Checksummen-Datei pro Asset, deshalb hier nur der
# Download - dafuer ueber https von GitHub Releases.
log "k3d $K3D_VERSION"
curl -fsSL --retry 3 --max-time 300 \
  -o "$TMP/k3d" \
  "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-${OS}-${ARCH}" \
  || die "k3d-Download fehlgeschlagen"
install -m 0755 "$TMP/k3d" "$BIN_DIR/k3d"
ok "$BIN_DIR/k3d"

# --- k9s ----------------------------------------------------------------------
log "k9s $K9S_VERSION"
k9s_tgz="k9s_${OS_TITLE}_${ARCH}.tar.gz"
want="$(
  curl -fsSL --max-time 60 \
    "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/checksums.sha256" \
    | grep " \+${k9s_tgz}\$" | awk '{print $1}' | head -1
)"
[[ -n "$want" ]] || die "keine Checksumme fuer $k9s_tgz gefunden"
fetch_verify \
  "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/${k9s_tgz}" \
  "$TMP/$k9s_tgz" "$want"
tar -xzf "$TMP/$k9s_tgz" -C "$TMP" k9s
install -m 0755 "$TMP/k9s" "$BIN_DIR/k9s"
ok "$BIN_DIR/k9s"

# --- Completions --------------------------------------------------------------
# Erst jetzt, mit den frisch installierten Binaries - sonst generiert eine alte
# Version im PATH die Completion.
log "Completions erzeugen"
export PATH="$BIN_DIR:$PATH"

gen() {
  local tool="$1" shell="$2" out="$3"
  if "$BIN_DIR/$tool" completion "$shell" >"$out" 2>/dev/null && [[ -s "$out" ]]; then
    return 0
  fi
  rm -f "$out"
  return 1
}

for tool in kubectl helm k3d k9s; do
  gen "$tool" bash "$BASH_COMP_DIR/$tool" \
    && ok "bash: $tool" \
    || warn "bash-Completion fuer $tool fehlgeschlagen"
  # zsh erwartet den Dateinamen _<tool> im fpath.
  gen "$tool" zsh "$ZSH_COMP_DIR/_$tool" \
    && ok "zsh:  $tool" \
    || warn "zsh-Completion fuer $tool fehlgeschlagen"
done

# --- Shell-Konfiguration ------------------------------------------------------
# In einen markierten Block schreiben, damit ein zweiter Lauf ihn ersetzt statt
# ihn ein zweites Mal anzuhaengen.
write_block() {
  local rc="$1" shell="$2" tmp
  [[ -e "$rc" ]] || touch "$rc"
  tmp="$(mktemp)"
  sed "/^${MARKER}\$/,/^${MARKER_END}\$/d" "$rc" >"$tmp"
  {
    printf '%s\n' "$MARKER"
    printf 'export PATH="%s:$PATH"\n' "$BIN_DIR"
    if [[ "$shell" == bash ]]; then
      cat <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for _f in "$BASH_COMP_DIR"/*; do [ -r "\$_f" ] && . "\$_f"; done; unset _f
alias k=kubectl
# Die Completion der Abkuerzung braucht die kubectl-Completion davor, sonst
# scheitert sie mit "__start_kubectl: function not found".
complete -o default -F __start_kubectl k 2>/dev/null || true
EOF
    else
      cat <<EOF
fpath=("$ZSH_COMP_DIR" \$fpath)
autoload -Uz compinit && compinit -u
alias k=kubectl
compdef k=kubectl
EOF
    fi
    printf '%s\n' "$MARKER_END"
  } >>"$tmp"
  mv "$tmp" "$rc"
  ok "$rc aktualisiert"
}

log "Shell-Konfiguration"
write_block "$HOME/.bashrc" bash
[[ -n "${ZSH_VERSION:-}" || -e "$HOME/.zshrc" || "$(basename "${SHELL:-}")" == zsh ]] \
  && write_block "$HOME/.zshrc" zsh

# --- Abschluss ----------------------------------------------------------------
log "Versionen"
"$BIN_DIR/kubectl" version --client 2>/dev/null | head -1 | sed 's/^/  /'
"$BIN_DIR/helm" version --short 2>/dev/null | sed 's/^/  helm /'
"$BIN_DIR/k3d" version 2>/dev/null | head -1 | sed 's/^/  /'
"$BIN_DIR/k9s" version --short 2>/dev/null | head -3 | sed 's/^/  /' || true

cat <<EOF

${c_ok}Fertig.${c_off} Neue Shell oeffnen oder:

    source ~/.bashrc      # bzw. ~/.zshrc

Danach pruefen:

    ./scripts/setup-tools.sh --check

Und dann das Cluster bauen (machen wir gemeinsam):

    k3d cluster create homelab \\
      --image rancher/k3s:v1.36.4-k3s1 \\
      -p "8080:80@loadbalancer"
    kubectl get nodes
EOF

# CLAUDE.md

Orientation for Claude Code. Keep this short; README.md has the full install/run walkthrough.

## Intent

This repo is **not** just a demo — it's a reproducible test harness for Root Cause Analysis agents
(e.g. [orca-agent](https://github.com/BenedatLLC/orca-agent)). The goal is to run the upstream
[OpenTelemetry demo app](https://github.com/open-telemetry/opentelemetry-demo) in Minikube, add
`kube-state-metrics`, and wire Grafana alerts through to Slack so an RCA agent has realistic
failure signals to consume.

The host is typically a Linux server accessed remotely from a Mac/Linux laptop, so most `kubectl`
and port-forward commands bind to `0.0.0.0`.

## Layout

- `README.md` — install + run walkthrough (source of truth for commands)
- `Makefile` — wrapper around `minikube` / `helm` / `kubectl port-forward`. Targets are grouped
  by prefix: `mk-*` (minikube), `otel-*` (demo app), `prom-*` + `ksm-forward` (kube-state-metrics
  / Prometheus). See the "Reference: proxies and forwards" table in README.md for what each
  forward is for — most are optional and only `otel-forward` is needed for normal use.
- `.envrc` / `envrc.template` — direnv config. Pins `MINIKUBE_HOME=$PWD` (repo-local minikube
  state in `./.minikube/`) and sets `APISERVER_IP`, the LAN IP baked into the apiserver cert
  via `minikube start --apiserver-ips=$APISERVER_IP` so remote kubectl works. `.envrc` is
  gitignored; users copy `envrc.template` and edit it.
- `grafana-config/` — example JSON exports for a Slack contact point, a CrashLoopBackOff
  dashboard, and the alert rule. Currently imported through the Grafana UI, not auto-provisioned.
- `RCA/` — narrative write-ups of real incidents reproduced in this env (e.g. `CrashLoop.md`).
  Useful as ground truth for evaluating RCA agent output.
- `urls.md` — shortcut list of UIs (demo app, Grafana, Jaeger, load generator, flagd) — all
  served behind `frontend-proxy` on `:8080`.

## Key facts that aren't obvious from the code

- **Helm release name is `my-otel-demo`** (hardcoded in Makefile `otel-setup`). Any `helm upgrade`
  / `helm get values` must use this name.
- **kube-state-metrics is installed separately** in the `kube-system` namespace. The demo's
  built-in Prometheus only scrapes it after applying `otel-new-values.yaml` via
  `helm upgrade -f otel-new-values.yaml`. The `CrashLoopBackOff` alert depends on this —
  without it, `kube_pod_container_status_waiting_reason` is unavailable.
- **The prometheus subchart concatenates scrape configs, it does not replace.** The ConfigMap
  template (`charts/prometheus/templates/cm.yaml`) appends
  `serverFiles."prometheus.yml".scrape_configs` (our override) to `prometheus.scrapeConfigs`
  (chart defaults). So `otel-new-values.yaml` must contain *only* the new kube-state-metrics
  job, not a copy of the defaults — otherwise you get duplicate job names (e.g. two
  `prometheus` jobs) and Prometheus fails to start. This bit the project once already; see
  the longer writeup in the README's "What `otel-new-values.yaml` contains and why".
- **Memory tweaks are documented but not captured as code.** README "Configuration Changes"
  describes the bumps (`ad` 300→400Mi, `fraud-detection` 300→600Mi, `prometheus-server`
  300→500Mi, `kafka` 600→800Mi) but they are **not** in `otel-new-values.yaml` — they were
  applied ad hoc and will not survive a fresh install. Folding them into the values override
  is on the README Roadmap.
- **`mk-start` reads `APISERVER_IP` from the environment** (set in `.envrc`). If it's unset,
  the target fails fast with a pointer to `envrc.template`.
- **Everything goes through `frontend-proxy:8080`** once `make otel-forward` is running.
  Grafana is at `/grafana`, Jaeger at `/jaeger/ui/search`, load generator at `/loadgen/`
  (trailing slash required), flagd UI at `/feature`.
- **The dashboard is not behind `frontend-proxy`.** For remote access use `make mk-proxy`
  (kubectl API proxy on :8001). For local-on-host use `make mk-dashboard`. The addon must be
  enabled once — `mk-dashboard` or `mk-dashboard-remote` does that.
- **There is no Make target for the `helm upgrade -f otel-new-values.yaml` step** — it's
  described in the README but still needs to be run manually after `prom-kube-setup`.

## Typical workflows

Fresh start on the host:
```
make mk-start       # minikube up
make otel-setup     # helm install
make otel-forward   # port-forward frontend-proxy (blocking)
```

Remote access from laptop: see README "Remote access to minikube" — requires copying
`~/.kube/config` + certs and either a proxy or an ssh tunnel to `:8443`.

Grafana alert setup is currently manual through the UI using `grafana-config/*.json` as
reference (screenshots in `grafana-config/pictures/`).

## Open work (see README "Roadmap" for the living list)

- Capture the OOM memory bumps as entries in `otel-new-values.yaml`.
- Automate Grafana configuration (provisioning files or API calls) instead of UI import.
- Optionally auto-detect `APISERVER_IP` in the Makefile.

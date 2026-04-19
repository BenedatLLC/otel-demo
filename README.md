# otel-demo
This repo contains instructions and scripts to run the [open telemetry demo app](https://github.com/open-telemetry/opentelemetry-demo)
in Minikube.

## Installation

### Installation on Debian/Ubuntu/PopOS Linux
You need to have [direnv](https://direnv.net/) installed. If you do not already have it,
you can install the Debian package:

```sh
sudo apt-get install direnv
```

Next, install minikube:

```sh
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb
```

Download the latest release of Helm for your platform from
[GitHub](https://github.com/helm/helm/releases). You can untar the archive as follows:

```sh
tar xzf helm-v3.18.2-linux-amd64.tar.gz
```

Replace 3.18.2 with the latest version.

Now, copy the `helm` executable to `~/bin/helm`.

Download and install the `kubectl` executable:
https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux

### Configure the environment
Copy the envrc template and adjust it for your host, then let direnv load it:

```sh
cp envrc.template .envrc
# edit .envrc and set APISERVER_IP to the LAN IP of this host
#   (you can get a candidate with: hostname -I | awk '{print $1}')
direnv allow
```

`.envrc` sets two things:
* `MINIKUBE_HOME=$PWD` so minikube state lives in `./.minikube/` (repo-local) instead of
  `~/.minikube`.
* `APISERVER_IP` — the LAN IP baked into the minikube apiserver cert via
  `--apiserver-ips=...`, so a remote `kubectl` (e.g. from a laptop on the same network)
  can connect without cert errors. The `mk-start` Makefile target reads this env var.

Now run `make mk-start` (or `minikube start` with the appropriate flags).

### Metrics server
You can enable basic kubernetes metrics by running `minikube addons enable metrics-server`

### Accessing the Kubernetes dashboard
How you reach the dashboard depends on where your browser is:

**Browser on the same host as minikube** — one command:
```sh
make mk-dashboard    # runs `minikube dashboard`; enables the addon and opens a browser
```

**Browser on a different machine (the typical remote setup)** — use the `kubectl` API proxy.
Leave it running in its own shell:
```sh
make mk-proxy        # runs `kubectl proxy --address=0.0.0.0` on port 8001
```

Then from any machine on the LAN:
```
http://REMOTE-HOST:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/#/workloads?namespace=default
```

The dashboard addon must be enabled at least once. If you've never run `make mk-dashboard`,
run `make mk-dashboard-remote` once (it enables the addon and prints the local URL without
opening a browser) — you can ignore the URL it prints; after that the `mk-proxy` URL above
will work.

### Starting the otel demo app
Install the chart:
```sh
make otel-setup      # helm install my-otel-demo open-telemetry/opentelemetry-demo
```

Watch the rollout in the Kubernetes dashboard (see previous section). Once all pods are
Running, expose the demo's frontend-proxy on port 8080:
```sh
make otel-forward    # kubectl port-forward svc/frontend-proxy 8080:8080
```

Leave this running. The frontend-proxy fronts the demo app *and* most of the built-in
observability UIs, all on port 8080:

| URL | What |
|---|---|
| `http://HOSTNAME:8080/` | Demo app (astronomy shop) |
| `http://HOSTNAME:8080/grafana` | Grafana |
| `http://HOSTNAME:8080/jaeger/ui/search` | Jaeger |
| `http://HOSTNAME:8080/loadgen/` | Load generator (trailing slash required) |
| `http://HOSTNAME:8080/feature` | flagd feature-flag UI |

### Adding kube-state-metrics
The OpenTelemetry demo's bundled Prometheus does not scrape `kube-state-metrics` out of the
box, so metrics like `kube_pod_container_status_waiting_reason` (which the CrashLoopBackOff
alert depends on) are unavailable until we add a scrape job for it. That's what
`otel-new-values.yaml` in this repo is for.

First install kube-state-metrics (the Makefile target `prom-kube-setup` also adds the
`prometheus-community` helm repo):
```sh
make prom-kube-setup
# equivalent to:
#   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#   helm repo update
#   helm install kube-state-metrics prometheus-community/kube-state-metrics \
#     --namespace kube-system --create-namespace
```

Then apply the scrape config override shipped with this repo (there is no Make target for
this step yet — it's a one-line `helm upgrade`):
```sh
helm upgrade my-otel-demo open-telemetry/opentelemetry-demo --values otel-new-values.yaml
```

#### What `otel-new-values.yaml` contains and why

The file scopes a single Helm values override: `prometheus.serverFiles."prometheus.yml".scrape_configs`.
The only *new* addition is the `kube-state-metrics` job near the top:

```yaml
- job_name: kube-state-metrics
  static_configs:
  - targets:
    - kube-state-metrics.kube-system.svc.cluster.local:8080
```

Every other scrape job in that file (`prometheus`, `kubernetes-apiservers`, `kubernetes-nodes`,
`kubernetes-nodes-cadvisor`, `kubernetes-service-endpoints[-slow]`, `prometheus-pushgateway`,
`kubernetes-services`, `kubernetes-pods[-slow]`) is a verbatim copy of the chart's defaults.
They have to be preserved because Helm **replaces** the `scrape_configs` list rather than
merging it — dropping the defaults would kill every other scrape target.

To regenerate the file if upstream defaults drift, start from the installed release and edit:
```sh
helm get values my-otel-demo -a > otel-current-values.yaml
cp otel-current-values.yaml otel-new-values.yaml
vi otel-new-values.yaml  # keep only prometheus.serverFiles, add the kube-state-metrics job
helm upgrade my-otel-demo open-telemetry/opentelemetry-demo --values otel-new-values.yaml
```

To verify kube-state-metrics is publishing what you expect, forward its port (useful
mainly for debugging — Prometheus already scrapes it in-cluster):
```sh
make ksm-forward     # kubectl port-forward -n kube-system svc/kube-state-metrics 8081:8080
```

Now go to http://HOSTNAME:8081/metrics and search for `kube_pod_container_status_waiting_reason`.

### Inspecting Prometheus directly
If you want to run PromQL queries against Prometheus without going through Grafana, expose
the Prometheus service on port 9090:
```sh
make prom-forward    # kubectl port-forward svc/prometheus 9090:9090
```

Then browse to http://HOSTNAME:9090. This is optional — Grafana (via `otel-forward`) already
uses this Prometheus as its datasource.

### Grafana alert configuration
Grafana itself is reached through `otel-forward` (http://HOSTNAME:8080/grafana). See
[grafana-config/README.md](grafana-config/README.md) for details on configuring contact
points, dashboards, and alert rules.

## Reference: proxies and forwards

All of these run in the foreground and need their own terminal (or `tmux`/`screen` pane).
Only `otel-forward` is required for normal use of the demo; the rest are for dashboard
access or debugging.

| Make target | Command | Host port | What it exposes | When you need it |
|---|---|---|---|---|
| `mk-dashboard` | `minikube dashboard` | auto (browser-opened) | Kubernetes dashboard | Local use on the host, GUI browser available |
| `mk-dashboard-remote` | `minikube dashboard --url` | local 127.0.0.1 only | Prints dashboard URL; enables the addon | Run once to enable the addon; real access comes via `mk-proxy` |
| `mk-proxy` | `kubectl proxy --address=0.0.0.0` | 8001 | Whole kube API (including dashboard) | Accessing the dashboard from a remote laptop |
| `mk-tunnel` | `minikube tunnel` | varies | LoadBalancer-type services | Not needed for this demo — it uses ClusterIP services |
| `otel-forward` | `kubectl port-forward svc/frontend-proxy` | 8080 | Demo app + Grafana + Jaeger + loadgen + flagd | **Always** — this is how you use the demo |
| `prom-forward` | `kubectl port-forward svc/prometheus` | 9090 | Prometheus UI | Debugging PromQL directly |
| `ksm-forward` | `kubectl port-forward svc/kube-state-metrics` | 8081 | kube-state-metrics `/metrics` | Debugging ksm scrape output |

## Remote access to minikube

I found it useful to run `kubectl` on my laptop to access minikube on a remote host. To do this, I had to do the following:

1. You need the kubnetes config file on your local machine. The file can be usually be found at `~/.kube/config` on the
   remote host. You can `scp` it over to whereever you want to keep it on your laptop.
2. You need local copies of the certificates created by minikube and referenced in the config file. These will
   include the certificate authority (`ca.crt`), the client certificate (`client.crt`), and the client key (`client.key`).
   Copy them to your laptop and then update the paths in the kubernetes confile file to point to the correct local locations.
3. The API server entry ("server" in the config file) is likely pointing to an IP on the host's private network. You can
   either run a proxy on the host or run an ssh tunnel from the client. Here's how to run a client-side tunnel:
   ```sh
   HOST_PRIVATE_IP="..." # you can get this via `minikube ip`
   HOST_PUBLIC_IP="..." # public ip or hostname for the remote host
   ssh -L 8443:$(HOST_PRIVATE_IP):8443 $(HOST_PUBLIC_IP) -N
   ```
4. You need to adjust the `server` entry in the config file. If you did client-side tunneling, this should point to 
   https://localhost:8443.
5. On your labtop, set the environment variable `KUBECONFIG` to point to your new kubernetes config file.
6. As a sanity test, you can run something like `kubectl get pods`

## Configuration Changes
### Address OOM issues
* Updated the memory for the "ad" deployment from 300Mi to 400Mi
* Updated the memory for the "fraud-detection" deployment from 300Mi to 600Mi
* Updated the memory for the "prometheus-server" container in the "prometheus" deployment from 300Mi to 500Mi
* Updated the memory for the kafka deployment from 600Mi to 800Mi

See [RCA/CrashLoop.md](RCA/CrashLoop.md) for details.

> **Known gap:** these memory bumps are *not* currently captured in `otel-new-values.yaml` —
> they were applied ad hoc (e.g. via `kubectl edit`) and will not be reproduced by a fresh
> `make otel-setup` + `helm upgrade -f otel-new-values.yaml`. Folding them into the values
> override is on the roadmap below.

## Roadmap

* **Capture the OOM memory bumps as code.** Add `components.<name>.resources.limits/requests`
  overrides for `ad`, `fraud-detection`, `prometheus-server`, and `kafka` to
  `otel-new-values.yaml` so a fresh install reproduces the same resource profile.
* **Automate Grafana configuration.** The Slack contact point, CrashLoopBackOff dashboard, and
  alert rule in [grafana-config/](grafana-config/) are currently imported manually through the
  UI. Replace that with either Grafana file-based provisioning (mounted via the Helm
  `grafana.dashboardProviders` / `grafana.notifiers` values) or a small script that calls the
  Grafana HTTP API against the running instance.
* **Parameterize the host IP.** `APISERVER_IP` is now in `.envrc` / `envrc.template`, but the
  Makefile could auto-detect it (e.g. `hostname -I | awk '{print $1}'`) if desired.

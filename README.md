# otel-demo
This repo contains instructions and scripts to run the [open telemetry demo app](https://github.com/open-telemetry/opentelemetry-demo)
in Minikube.

## Installation

### Prerequistes
You need to have [direnv](https://direnv.net/) installed. On Ubuntu Linux, this can be
installed via:


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

Now, run `minikube start`

### Remote proxy
If you are running minikube on a remote machine, keep the following running to have a remote proxy:
```sh
kubectl proxy --address='0.0.0.0' --accept-hosts='^*$'
```

You will be able to access the dashboard at:
http://REMOTE-HOST:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/#/workloads?namespace=default

### Metrics server
You can enable basic kubernetes metrics by running `minikube addons enable metrics-server`

### Adding kube-state-metrics
First install it:
```sh
helm install kube-state-metrics prometheus-community/kube-state-metrics   --namespace kube-system   --create-namespace
```

Get the current otel config and update the prometheus scraper config:
```sh
helm get values my-otel-demo -a > otel-current-values.yaml
cp otel-current-values.yaml otel-new-values.yaml
vi otel-new-values.yaml # edit the file, removing all the unchanged configuration and adding the new scraper config
helm upgrade my-otel-demo open-telemetry/opentelemetry-demo --values otel-new-values.yaml
```

To see the metrics that are being published, forward its port:
```sh
kubectl --namespace kube-system port-forward --address='0.0.0.0' svc/kube-state-metrics 8081:8080
```

Now go to http://HOSTNAME:8081/metrics

## Configuration Changes
### Address OOM issues
* Updated the memory for the "ad" deployment from 300Mi to 400Mi
* Updated the memory for the "fraud-detection" deployment from 300Mi to 600Mi
* Updated the memory for the "prometheus-server" container in the "prometheus" deployment from 300Mi to 500Mi
* Updated the memory for the kafka deployment from 600Mi to 800Mi

See [RCA/CrashLoop.md](RCA/CrashLoop.md) for details.


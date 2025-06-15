# otel-demo
Run the open telemetry demo app in Minikube

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
kubectl proxy --address='0.0.0.0' --accept-hosts='^*$
```

You will be able to access the dashboard at:
http://REMOTE-HOST:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/#/workloads?namespace=default

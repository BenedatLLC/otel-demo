SHELL=/bin/bash

OTEL_PORT=8080
K8S_MEMORY=10g

help:
	@echo general targets are:    help clean
	@echo minikube targets are:   mk-start mk-dashboard mk-dashboard-remote mk-proxy mk-tunnel mk-clean
	@echo otel targets are:       otel-setup otel-forward
	@echo prometheus targets are: prom-kube-setup prom-forward ksm-forward
	@echo repo targets are:       repo



mk-start:
	@if [ -z "$(APISERVER_IP)" ]; then echo "APISERVER_IP is not set — copy envrc.template to .envrc and adjust, then direnv allow"; exit 1; fi
	minikube start --driver=docker --alsologtostderr --memory=$(K8S_MEMORY) --listen-address='0.0.0.0' --apiserver-ips=$(APISERVER_IP)

mk-dashboard:
	minikube dashboard

# Run the dashboard without starting a browser
mk-dashboard-remote:
	minikube dashboard --url

mk-proxy:
	kubectl proxy --address='0.0.0.0' --accept-hosts='^*$$'

# allow host access to LoadBalancer services running in the minikube
mk-tunnel:
	minikube tunnel --bind-address='*'

mk-clean:
	-minikube stop
	minikube delete --purge

otel-setup:
	helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
	helm install my-otel-demo open-telemetry/opentelemetry-demo

otel-forward:
	kubectl --namespace default port-forward --address='0.0.0.0' svc/frontend-proxy 8080:8080

prom-kube-setup:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm install kube-state-metrics prometheus-community/kube-state-metrics --namespace kube-system --create-namespace

# prometheus is on port 9090 in the prometheus service
prom-forward:
	kubectl --namespace default port-forward --address='0.0.0.0' svc/prometheus 9090:9090

# kube-state-metrics exposes its /metrics endpoint on port 8080 of its service;
# forward to host port 8081 so you can browse http://HOSTNAME:8081/metrics.
ksm-forward:
	kubectl --namespace kube-system port-forward --address='0.0.0.0' svc/kube-state-metrics 8081:8080

repo: # local helm repository
	mkdir -p repo

clean: mk-clean
	rm -rf ./repo

.PHONY: help clean mk-start mk-dashboard mk-dashboard-remote mk-proxy mk-tunnel mk-clean otel-setup otel-forward prom-kube-setup prom-forward ksm-forward


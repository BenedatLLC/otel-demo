SHELL=/bin/bash

OTEL_PORT=8080
K8S_MEMORY=10g

help:
	@echo general targets are:    help clean
	@echo minikube targets are:   mk-start mk-dashboard mk-dashboard-remote mk-proxy mk-tunnel mk-clean
	@echo otel targets are:       otel-setup otel-forward
	@echo prometheus targets are: prom-forward
	@echo repo targets are:       repo



mk-start:
	minikube start --driver=docker --alsologtostderr --memory=$(K8S_MEMORY) --listen-address='0.0.0.0' --apiserver-ips=192.168.1.191

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

repo: # local helm repository
	mkdir -p repo

clean: mk-clean
	rm -rf ./repo

.PHONY: help clean mk-start mk-dashboard mk-dashboard-remote mk-tunnel mk-clean otel-setup otel-forward prom-forward


SHELL=/bin/bash

OTEL_PORT=8080

help:
	@echo general targets are:    help clean
	@echo minikube targets are:   mk-start mk-dashboard mk-tunnel mk-clean
	@echo otel targets are:       otel-setup
	@echo repo targets are:       repo



mk-start:
	minikube start --driver=docker --alsologtostderr

mk-dashboard:
	minikube dashboard

mk-tunnel:
	minikube tunnel

mk-clean:
	-minikube stop
	minikube delete --purge

otel-setup:
	helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
	helm install my-otel-demo open-telemetry/opentelemetry-demo
	kubectl --namespace default port-forward svc/frontend-proxy 8080:$(OTEL_PORT)


repo: # local helm repository
	mkdir -p repo

clean: mk-clean
	rm -rf ./repo

.PHONY: help clean mk-start mk-dashboard mk-tunnel mk-clean otel-setup


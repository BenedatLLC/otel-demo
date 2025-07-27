# Grafana configuration

This directory contains additional configurations to Grafana to enable relevant alerts and send them
to grafana. There are three configuration files provided as examples:

1. `slack-contact-point.json` - defines a Grafana *contact point* for sending alerts to a Slack channel.
2. `custom-monitoring-dashboad.json` - sets up a monitoring dashboard
3. `alert-rules.json` - the alert rules (which send to the contact point)

## Metrics
We currently define one Prometheus query for our alert and dashboard:
```prometheus
sum by (pod, container) (kube_pod_container_status_waiting_reason{namespace="default", reason="CrashLoopBackOff"})
```

This query gets the number of containers in the CrashLoopBackOff state and groups them by pod and container.

## Grafana configuration through UI
Here's the relevant configuration pages in the Grafana UI.

### Slack contact point
![Contact point configuration](contact-point-configuration.png)

### Dashboard
![Dashboard configuration](dashboard-configuration.png)

### Alert
![Alert configuration](alert-configuration)


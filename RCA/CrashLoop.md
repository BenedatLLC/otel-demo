# Root cause analysis examples: Crash Loop due to OOM

## Symptoms
The fraud-detection deployment shows red in the dashboard

Message was:
```
Back-off restarting failed container fraud-detection in pod fraud-detection-7db479d7f5-f9wxm_default(6b0ec6f8-227e-4c8b-a636-acdb1d473cb3)
```

The pod fraud-detection-7db479d7f5-f9wxm does indeed show the backoff event in its list of events in the dashboard.

### Diagnosis

I then ran:

```sh
kubectl describe pod fraud-detection-7db479d7f5-f9wxm -n default
```

Looking in the "Containers" section, I see:

```
Containers:
  fraud-detection:
    Container ID:   docker://becc856e1c2e7db4f38d5add852e203e1692653b41f6e73217bfde53e5215382
    Image:          ghcr.io/open-telemetry/demo:2.0.2-fraud-detection
    Image ID:       docker-pullable://ghcr.io/open-telemetry/demo@sha256:8b0a841c19f583a83b150bbd0609d85b3f09d19a75888d716bb234098f3385b4
    Port:           <none>
    Host Port:      <none>
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       Error
      Exit Code:    137
      Started:      Sat, 21 Jun 2025 11:05:55 -0700
      Finished:     Sat, 21 Jun 2025 11:05:57 -0700
    Ready:          False
    Restart Count:  187
    Limits:
      memory:  300Mi
    Requests:
      memory:  300Mi
    Environment:
      OTEL_SERVICE_NAME:                                   (v1:metadata.labels['app.kubernetes.io/component'])
      OTEL_COLLECTOR_NAME:                                otel-collector
      OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE:  cumulative
      KAFKA_ADDR:                                         kafka:9092
      FLAGD_HOST:                                         flagd
      FLAGD_PORT:                                         8013
      OTEL_EXPORTER_OTLP_ENDPOINT:                        http://$(OTEL_COLLECTOR_NAME):4318
      OTEL_RESOURCE_ATTRIBUTES:                           service.name=$(OTEL_SERVICE_NAME),service.namespace=opentelemetry-demo,service.version=2.0.2
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-bcj4v (ro)
```

Specifically, the last state shows that the pod was terminated with reason "Error" and an exit code of 137.
A search for that exit code indicates it is typically an OOM. It can sometimes be caused by a failed health check.


## Resolution
1. Updated the memory for the "fraud-detection" container in the "fraud-detection" deployment from 300Mi to 400Mi and restarted
2. The problem still happened
3. Increased memory from 400Mi to 600Mi and restarted
4. Problem fixed!

## Metrics and alerts
Here's a metric you can use:
```
sum by (pod, container) (kube_pod_container_status_waiting_reason{namespace="default", reason="CrashLoopBackOff"})
```

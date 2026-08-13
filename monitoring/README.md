# Monitoring and Logging

Expensy uses **Prometheus and Grafana** for Kubernetes monitoring and **Amazon CloudWatch** for centralized application logging.

## Prometheus and Grafana

Prometheus and Grafana are installed in EKS using the `kube-prometheus-stack` Helm chart.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

Verify the installation:

```bash
kubectl get pods -n monitoring
```

Access Grafana using port forwarding:

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana \
  -n monitoring 3001:80
```

Grafana is available at:

```text
http://localhost:3001
```

The Expensy dashboard monitors metrics including CPU and memory usage by pod.

The exported dashboard is stored at:

```text
monitoring/expensy-dashboard.json
```

It can be restored using **Grafana → Dashboards → New → Import**.

## CloudWatch Logging

Amazon CloudWatch Observability is used to collect application and container logs from the EKS cluster.

Verify the add-on:

```bash
aws eks describe-addon \
  --cluster-name eks-ahsan-final1 \
  --addon-name amazon-cloudwatch-observability \
  --region us-east-1 \
  --query 'addon.status' \
  --output text
```

Application logs are available in:

```text
/aws/containerinsights/eks-ahsan-final1/application
```

Logs can be viewed from:

**AWS Console → CloudWatch → Logs → Log groups**

Example CloudWatch Logs Insights query:

```text
fields @timestamp, @message
| filter @message like /Cache hit/
| sort @timestamp desc
| limit 100
```

Backend logs can also be viewed directly with:

```bash
kubectl logs -f deployment/expensy-backend -c backend
```

## Architecture

```text
EKS Workloads
   │
   ├── Prometheus → collects metrics
   │       ↓
   │    Grafana → dashboards
   │
   └── CloudWatch → centralized logs
```

Prometheus, Grafana, and CloudWatch are cluster-level components and are configured separately from the application CI/CD pipeline.
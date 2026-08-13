# Security and Compliance

This document summarizes the security and compliance practices used for the Expensy EKS deployment.

## IAM and Access Control

The EKS cluster and managed worker nodes use dedicated **AWS IAM roles** instead of AWS root credentials.

AWS CLI access is performed using an **IAM user** rather than the root account.

The CloudWatch agent uses **EKS Pod Identity** with a dedicated IAM role and the `CloudWatchAgentServerPolicy`.

## Secrets Management

Sensitive values such as MongoDB credentials, the database URI, and Redis password are stored in a Kubernetes Secret named:

```text
expensy-secrets
```

Deployments access these values using `secretKeyRef`.

The real secret manifest:

```text
kubernetes/secrets.yaml
```

is excluded from Git using `.gitignore`. A `secrets.example.yaml` containing placeholder values is committed instead.

For CI/CD deployments, sensitive values are stored using **GitHub Actions Secrets**. The pipeline creates or updates the Kubernetes Secret during deployment, preventing credentials from being stored in the repository.

## Network Security

EKS worker nodes are deployed in **private subnets**, while public subnets are used for internet-facing resources.

AWS Security Groups and VPC networking are used to control network access.

MongoDB, Redis, frontend, and backend use Kubernetes `ClusterIP` services and are not directly exposed to the internet.

External application traffic enters through the **NGINX Ingress Controller and AWS LoadBalancer**.

## TLS / HTTPS

The application is available securely at:

```text
https://expensy-ahsan.ironlabs.online
```

DNS is managed using **Amazon Route 53**.

TLS certificates are issued by **Let's Encrypt** and managed automatically using **cert-manager**.

NGINX Ingress is configured with TLS so browser traffic to both the frontend and backend API uses HTTPS.

## Monitoring and Logging

**Prometheus and Grafana** are used for Kubernetes metrics and visualization.

**Amazon CloudWatch Container Insights** provides centralized application and container logging.

Application logs are available under:

```text
/aws/containerinsights/eks-ahsan-final1/application
```

## Retention Policy (Default)

- Prometheus: 10 days
- CloudWatch: Never Expire

## Data Protection and Compliance

Application credentials are separated from source code and are not stored in Kubernetes ConfigMaps or committed to Git.

MongoDB and Redis are accessible only through internal Kubernetes services.

The EKS environment is deployed in the AWS **us-east-1** region.

Persistent database storage is not configured for this project.

The deployment demonstrates basic security practices including:

- IAM-based access control
- Secret separation from source code
- Private worker-node networking
- Internal database services
- HTTPS encryption in transit
- Centralized logging and monitoring

Application data is hosted in the AWS us-east-1 region. This project is for educational purposes and is not formally certified for GDPR, HIPAA, or other compliance frameworks.
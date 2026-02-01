# Open Embed Router - Deployment Guide

This guide covers production deployment scenarios for Open Embed Router.

## Table of Contents

- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [SSL Certificate Setup](#ssl-certificate-setup)
- [Local Production Deployment](#local-production-deployment)
- [Cloud Deployment](#cloud-deployment)
- [Security Hardening](#security-hardening)
- [Monitoring and Logging](#monitoring-and-logging)
- [Backup and Recovery](#backup-and-recovery)
- [Scaling](#scaling)
- [Troubleshooting](#troubleshooting)

## Pre-Deployment Checklist

Before deploying to production:

- [ ] Review and update environment variables in `.env`
- [ ] Choose your provider (Ollama, OpenAI, etc.)
- [ ] Generate or obtain SSL certificates
- [ ] Configure firewall rules (ports 80, 443)
- [ ] Set up monitoring and alerting
- [ ] Test locally with Docker Compose
- [ ] Configure DNS (if using custom domain)
- [ ] Set up log aggregation
- [ ] Document deployment details
- [ ] Create runbook for common issues
- [ ] Test backup and recovery procedures

## SSL Certificate Setup

### Option 1: Let's Encrypt (Recommended for Production)

Let's Encrypt provides free, automated SSL certificates.

#### Prerequisites

- Domain name pointing to your server
- Ports 80 and 443 accessible from internet
- Certbot installed on host machine

#### Setup Steps

1. **Install Certbot**:

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install certbot

# CentOS/RHEL
sudo yum install certbot

# macOS
brew install certbot
```

2. **Generate certificates**:

```bash
sudo certbot certonly --standalone -d your-domain.com
```

Or use the provided script:

```bash
chmod +x scripts/setup-letsencrypt.sh
sudo ./scripts/setup-letsencrypt.sh your-domain.com
```

3. **Copy certificates to nginx directory**:

```bash
sudo mkdir -p nginx/ssl
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem nginx/ssl/key.pem
sudo chmod 644 nginx/ssl/cert.pem
sudo chmod 600 nginx/ssl/key.pem
```

4. **Set up auto-renewal**:

```bash
# Test renewal
sudo certbot renew --dry-run

# Add cron job for auto-renewal
sudo crontab -e
# Add this line:
0 0 * * * certbot renew --quiet && cp /etc/letsencrypt/live/your-domain.com/fullchain.pem /path/to/nginx/ssl/cert.pem && cp /etc/letsencrypt/live/your-domain.com/privkey.pem /path/to/nginx/ssl/key.pem && docker compose -f /path/to/docker-compose.https.yml restart nginx
```

### Option 2: Self-Signed Certificates (Development/Testing)

For development or internal testing only.

#### Generate Self-Signed Certificate

```bash
chmod +x scripts/generate-ssl.sh
./scripts/generate-ssl.sh
```

Or manually:

```bash
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
```

**Note**: Self-signed certificates will show security warnings in browsers.

### Option 3: Custom Certificates

If you have certificates from a commercial CA:

1. Copy certificate and key to `nginx/ssl/`:

```bash
cp your-cert.crt nginx/ssl/cert.pem
cp your-key.key nginx/ssl/key.pem
chmod 644 nginx/ssl/cert.pem
chmod 600 nginx/ssl/key.pem
```

2. If you have intermediate certificates, concatenate them:

```bash
cat your-cert.crt intermediate.crt > nginx/ssl/cert.pem
```

## Local Production Deployment

Deploy with HTTPS on a local server or VPS.

### 1. Prepare Environment

```bash
# Clone repository
git clone <repository-url>
cd open-embed-router

# Copy and configure environment
cp .env.example .env
nano .env  # Edit with your values
```

### 2. Configure Provider

Edit `.env` to configure your embedding provider:

**For Ollama (local):**

```bash
PROVIDER=ollama
PROVIDER_BASE_URL=http://host.docker.internal:11434
TEST_MODEL=nomic-embed-text
```

**For OpenAI:**

```bash
PROVIDER=openai
PROVIDER_BASE_URL=https://api.openai.com
API_KEY=sk-your-openai-key
TEST_MODEL=text-embedding-3-small
```

### 3. Set Up SSL Certificates

Follow [SSL Certificate Setup](#ssl-certificate-setup) above.

### 4. Update nginx Configuration

Edit `nginx/nginx.conf` if needed:

```bash
nano nginx/nginx.conf
```

Update `server_name` if using a custom domain:

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    # ...
}
```

### 5. Deploy with Docker Compose

```bash
# Build and start services
docker compose -f docker-compose.https.yml up --build -d

# Check status
docker compose -f docker-compose.https.yml ps

# View logs
docker compose -f docker-compose.https.yml logs -f
```

### 6. Verify Deployment

```bash
# Test health check
curl https://your-domain.com/health

# Test embeddings endpoint (Ollama)
curl -X POST https://your-domain.com/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "nomic-embed-text", "input": "test"}'

# Test embeddings endpoint (OpenAI)
curl -X POST https://your-domain.com/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key" \
  -d '{"model": "text-embedding-3-small", "input": "test"}'
```

### 7. Configure Firewall

```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## Cloud Deployment

### AWS Deployment

#### Option 1: ECS (Elastic Container Service)

1. **Build and push Docker image**:

```bash
# Authenticate to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and tag image
docker build -t open-embed-router .
docker tag open-embed-router:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/open-embed-router:latest

# Push to ECR
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/open-embed-router:latest
```

2. **Create ECS task definition**:

```json
{
  "family": "open-embed-router",
  "containerDefinitions": [
    {
      "name": "open-embed-router",
      "image": "<account-id>.dkr.ecr.us-east-1.amazonaws.com/open-embed-router:latest",
      "portMappings": [
        {
          "containerPort": 9000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        { "name": "PORT", "value": "9000" },
        { "name": "Open Embed Router_BASE", "value": "https://api.openai.com" },
        { "name": "LOG_LEVEL", "value": "info" }
      ],
      "secrets": [
        {
          "name": "Open Embed Router_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:<account-id>:secret:Open Embed Router-key"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/open-embed-router",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "512"
}
```

3. **Create ECS service with ALB**:

- Create Application Load Balancer
- Configure target group (port 9000)
- Add HTTPS listener with SSL certificate
- Create ECS service with ALB integration

#### Option 2: EC2

1. **Launch EC2 instance** (Ubuntu 22.04 LTS recommended)

2. **Install Docker and Docker Compose**:

```bash
# Connect to instance
ssh -i your-key.pem ubuntu@<instance-ip>

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

3. **Deploy application**:

```bash
# Clone repository
git clone <repository-url>
cd open-embed-router

# Configure environment
cp .env.example .env
nano .env

# Set up SSL certificates
./scripts/setup-letsencrypt.sh your-domain.com

# Deploy
docker compose -f docker-compose.https.yml up -d
```

4. **Configure security group**:

- Allow inbound: 80 (HTTP), 443 (HTTPS)
- Allow outbound: All traffic

### GCP Deployment

#### Option 1: Cloud Run

1. **Build and push to Container Registry**:

```bash
# Set project
gcloud config set project <project-id>

# Build and push
gcloud builds submit --tag gcr.io/<project-id>/open-embed-router

# Or use Docker
docker build -t gcr.io/<project-id>/open-embed-router .
docker push gcr.io/<project-id>/open-embed-router
```

2. **Deploy to Cloud Run**:

```bash
gcloud run deploy open-embed-router \
  --image gcr.io/<project-id>/open-embed-router \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 9000 \
  --set-env-vars "Open Embed Router_BASE=https://api.openai.com,LOG_LEVEL=info" \
  --set-secrets "Open Embed Router_KEY=Open Embed Router-key:latest"
```

3. **Configure custom domain** (optional):

```bash
gcloud run domain-mappings create \
  --service open-embed-router \
  --domain your-domain.com \
  --region us-central1
```

#### Option 2: GCE (Compute Engine)

Similar to AWS EC2 deployment above.

### Azure Deployment

#### Option 1: Container Instances

1. **Create resource group**:

```bash
az group create --name Open Embed Router-rg --location eastus
```

2. **Create container instance**:

```bash
az container create \
  --resource-group Open Embed Router-rg \
  --name open-embed-router \
  --image <your-registry>/open-embed-router:latest \
  --dns-name-label open-embed-router \
  --ports 9000 \
  --environment-variables \
    PORT=9000 \
    Open Embed Router_BASE=https://api.openai.com \
  --secure-environment-variables \
    Open Embed Router_KEY=<your-key>
```

3. **Configure Application Gateway** for HTTPS.

#### Option 2: AKS (Azure Kubernetes Service)

See [Kubernetes Deployment](#kubernetes-deployment) below.

### DigitalOcean Deployment

#### Option 1: App Platform

1. **Create app from GitHub**:

- Connect repository
- Select Dockerfile deployment
- Configure environment variables
- Deploy

#### Option 2: Droplet

Similar to AWS EC2 deployment above.

## Kubernetes Deployment

For large-scale deployments.

### 1. Create Kubernetes Manifests

**deployment.yaml**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: open-embed-router
spec:
  replicas: 3
  selector:
    matchLabels:
      app: open-embed-router
  template:
    metadata:
      labels:
        app: open-embed-router
    spec:
      containers:
        - name: open-embed-router
          image: <your-registry>/open-embed-router:latest
          ports:
            - containerPort: 9000
          env:
            - name: PORT
              value: "9000"
            - name: Open Embed Router_BASE
              value: "https://api.openai.com"
            - name: Open Embed Router_KEY
              valueFrom:
                secretKeyRef:
                  name: Open Embed Router-secrets
                  key: api-key
          livenessProbe:
            httpGet:
              path: /health
              port: 9000
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: 9000
            initialDelaySeconds: 5
            periodSeconds: 10
```

**service.yaml**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: open-embed-router
spec:
  selector:
    app: open-embed-router
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9000
  type: LoadBalancer
```

**ingress.yaml** (with cert-manager for HTTPS):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: open-embed-router
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - your-domain.com
      secretName: Open Embed Router-tls
  rules:
    - host: your-domain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: open-embed-router
                port:
                  number: 80
```

### 2. Deploy to Kubernetes

```bash
# Create secret
kubectl create secret generic Open Embed Router-secrets \
  --from-literal=api-key=your-api-key

# Apply manifests
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# Check status
kubectl get pods
kubectl get svc
kubectl get ingress
```

## Security Hardening

### 1. Environment Variables

Use secrets management instead of plain text:

**AWS Secrets Manager**:

```bash
aws secretsmanager create-secret \
  --name Open Embed Router-key \
  --secret-string "your-api-key"
```

**GCP Secret Manager**:

```bash
echo -n "your-api-key" | gcloud secrets create Open Embed Router-key --data-file=-
```

**Azure Key Vault**:

```bash
az keyvault secret set \
  --vault-name Open Embed Router-vault \
  --name Open Embed Router-key \
  --value "your-api-key"
```

### 2. Network Security

- Use VPC/VNet for isolation
- Configure security groups/firewall rules
- Enable DDoS protection
- Use private subnets for containers
- Implement rate limiting

### 3. Container Security

- Run as non-root user (add to Dockerfile)
- Scan images for vulnerabilities
- Use minimal base images (alpine)
- Keep dependencies updated
- Enable read-only filesystem where possible

### 4. SSL/TLS

- Use TLS 1.2+ only
- Strong cipher suites
- HSTS header
- Certificate pinning (optional)

### 5. Logging and Monitoring

- Don't log sensitive data (API keys, embeddings)
- Implement log aggregation
- Set up alerts for errors
- Monitor for suspicious activity

## Monitoring and Logging

### CloudWatch (AWS)

```bash
# Create log group
aws logs create-log-group --log-group-name /ecs/open-embed-router

# View logs
aws logs tail /ecs/open-embed-router --follow
```

### Cloud Logging (GCP)

```bash
# View logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=open-embed-router" --limit 50
```

### Application Insights (Azure)

Configure in Azure Portal.

### Self-Hosted (ELK Stack)

1. **Deploy ELK stack**
2. **Configure Filebeat** to ship logs
3. **Create Kibana dashboards**

### Prometheus + Grafana

Add metrics endpoint to application (future enhancement).

## Backup and Recovery

### 1. Configuration Backup

```bash
# Backup environment and configs
tar -czf Open Embed Router-backup-$(date +%Y%m%d).tar.gz \
  .env \
  nginx/nginx.conf \
  nginx/ssl/ \
  docker-compose*.yml
```

### 2. Log Backup

```bash
# Backup logs
tar -czf logs-backup-$(date +%Y%m%d).tar.gz logs/
```

### 3. Automated Backups

**Cron job**:

```bash
0 2 * * * /path/to/backup-script.sh
```

**Backup script** (`scripts/backup.sh`):

```bash
#!/bin/bash
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d)
tar -czf $BACKUP_DIR/Open Embed Router-$DATE.tar.gz /path/to/open-embed-router
find $BACKUP_DIR -name "Open Embed Router-*.tar.gz" -mtime +30 -delete
```

### 4. Disaster Recovery

1. **Restore from backup**:

```bash
tar -xzf Open Embed Router-backup-20260201.tar.gz
```

2. **Redeploy**:

```bash
docker compose -f docker-compose.https.yml up -d
```

## Scaling

### Horizontal Scaling

**Docker Compose**:

```bash
docker compose -f docker-compose.https.yml up -d --scale open-embed-router=3
```

**Kubernetes**:

```bash
kubectl scale deployment open-embed-router --replicas=5
```

**Cloud Auto-Scaling**:

- AWS: ECS Service Auto Scaling
- GCP: Cloud Run auto-scales automatically
- Azure: Container Instances scale sets

### Vertical Scaling

Increase container resources:

**Docker Compose**:

```yaml
services:
  open-embed-router:
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 2G
```

**Kubernetes**:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

### Load Balancing

- AWS: Application Load Balancer
- GCP: Cloud Load Balancing
- Azure: Application Gateway
- nginx: Upstream load balancing

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs open-embed-router

# Check container status
docker compose ps

# Inspect container
docker inspect open-embed-router
```

### SSL Certificate Issues

```bash
# Verify certificate
openssl x509 -in nginx/ssl/cert.pem -text -noout

# Test SSL connection
openssl s_client -connect your-domain.com:443
```

### High Memory Usage

```bash
# Check container stats
docker stats open-embed-router

# Increase memory limit
# Edit docker-compose.yml and add:
deploy:
  resources:
    limits:
      memory: 2G
```

### Network Connectivity Issues

```bash
# Test from container (OpenAI)
docker exec open-embed-router curl https://api.openai.com

# Test from container (Ollama on host)
docker exec open-embed-router curl http://host.docker.internal:11434/api/tags

# Check DNS resolution
docker exec open-embed-router nslookup api.openai.com

# Check firewall rules
sudo iptables -L
```

## Maintenance

### Update Application

```bash
# Pull latest code
git pull

# Rebuild and restart
docker compose -f docker-compose.https.yml up --build -d

# Verify
curl https://your-domain.com/health
```

### Rotate SSL Certificates

```bash
# Renew Let's Encrypt
sudo certbot renew

# Copy new certificates
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem nginx/ssl/key.pem

# Restart nginx
docker compose -f docker-compose.https.yml restart nginx
```

### Clean Up Old Logs

```bash
# Manual cleanup
find logs/ -name "*.log" -mtime +30 -delete

# Or let Winston handle it (configured in src/index.js)
```

## Support

For deployment issues:

1. Check logs: `docker compose logs -f`
2. Review [README.md](README.md) troubleshooting section
3. Consult [plans/technical-specification.md](plans/technical-specification.md)
4. Open GitHub issue with deployment details

## Conclusion

This guide covers common deployment scenarios. Adapt as needed for your specific infrastructure and requirements.

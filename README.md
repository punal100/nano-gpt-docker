# Open Embed Router

A robust, provider-agnostic Docker-based router that provides an OpenAI-compatible embeddings API. Supports multiple embedding providers including Ollama, OpenAI, NanoGPT, Together AI, and any OpenAI-compatible service.

## Features

✅ **Provider Agnostic** - Switch between Ollama, OpenAI, NanoGPT, and more with a single config change  
✅ **OpenAI-Compatible API** - Drop-in replacement for OpenAI embeddings endpoint  
✅ **Ollama Support** - Native integration with local Ollama server  
✅ **Transparent Proxy** - Forwards all `/api/*` and `/v1/*` requests to your provider  
✅ **Sequential Processing** - Handles batched requests one-by-one to avoid token limits  
✅ **Robust Retry Logic** - Exponential backoff with configurable attempts  
✅ **Startup Health Check** - Verifies provider connectivity on launch  
✅ **Production Logging** - Winston with daily rotation and retention policies  
✅ **HTTPS Support** - Optional nginx reverse proxy with SSL/TLS  
✅ **Docker Deployment** - Both basic (HTTP) and production (HTTPS) configurations  
✅ **Flexible Authentication** - Header forwarding with environment fallbacks

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- An embedding provider (Ollama, OpenAI, NanoGPT, etc.)

### Basic Setup (HTTP)

1. **Clone and configure**:

```bash
git clone <repository-url>
cd open-embed-router
cp .env.example .env
```

2. **Edit `.env` for your provider**:

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

**For NanoGPT:**

```bash
PROVIDER=openai
PROVIDER_BASE_URL=https://nano-gpt.com
API_KEY=sk-nano-your-key
TEST_MODEL=Qwen/Qwen3-Embedding-0.6B
```

3. **Build and run**:

```bash
docker compose up --build
```

4. **Test the router**:

```bash
curl http://localhost:9000/health
# {"ok":true,"provider":"ollama"}

curl -X POST http://localhost:9000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "nomic-embed-text", "input": "Hello world"}'
```

### Production Setup (HTTPS)

See [`DEPLOYMENT.md`](DEPLOYMENT.md) for detailed production deployment instructions including SSL certificate setup.

## Configuration

### Environment Variables

| Variable                  | Default                | Description                                    |
| ------------------------- | ---------------------- | ---------------------------------------------- |
| `PROVIDER`                | openai                 | Provider type: `openai` or `ollama`            |
| `PROVIDER_BASE_URL`       | http://localhost:11434 | Provider API base URL                          |
| `API_KEY`                 | ""                     | API key for the provider (optional for Ollama) |
| `X_PAYMENT`               | ""                     | Payment header (for X402 protocol)             |
| `PORT`                    | 9000                   | Server port                                    |
| `ROUTER_ATTEMPTS`         | 3                      | Retry attempts for failed requests             |
| `ROUTER_BACKOFF_MS`       | 500                    | Initial backoff delay in ms                    |
| `LOG_LEVEL`               | info                   | Logging level (error/warn/info/debug)          |
| `LOG_DIR`                 | /app/logs              | Log directory path                             |
| `STARTUP_CHECK`           | true                   | Enable startup health check                    |
| `TEST_MODEL`              | nomic-embed-text       | Model for health check                         |
| `REQUIRE_API_KEY`         | false                  | Require API key authentication                 |
| `IGNORE_INCOMING_API_KEY` | false                  | Use env key instead of request key             |
| `CLOUDFLARE_TUNNEL_TOKEN` | ""                     | Cloudflare tunnel token (optional)             |

### Provider Configuration

#### Ollama (Local)

```bash
PROVIDER=ollama
PROVIDER_BASE_URL=http://localhost:11434  # or http://host.docker.internal:11434 in Docker
API_KEY=                                   # Not needed for Ollama
TEST_MODEL=nomic-embed-text
```

#### OpenAI

```bash
PROVIDER=openai
PROVIDER_BASE_URL=https://api.openai.com
API_KEY=sk-your-openai-key
TEST_MODEL=text-embedding-3-small
```

#### NanoGPT

```bash
PROVIDER=openai
PROVIDER_BASE_URL=https://nano-gpt.com
API_KEY=sk-nano-your-key
TEST_MODEL=Qwen/Qwen3-Embedding-0.6B
```

#### Together AI

```bash
PROVIDER=openai
PROVIDER_BASE_URL=https://api.together.xyz
API_KEY=your-together-key
TEST_MODEL=togethercomputer/m2-bert-80M-8k-retrieval
```

### Authentication Modes

The router supports three authentication modes:

#### 1. Public Access (Default)

```bash
REQUIRE_API_KEY=false
```

Anyone can access the API without providing an API key. The router will use the `API_KEY` from environment variables.

**Use case**: Local development or when you want unrestricted access.

#### 2. Private Access (API Key Required)

```bash
REQUIRE_API_KEY=true
API_KEY=your-secret-key
```

Clients must provide the correct API key that matches `API_KEY`. Requests with invalid or missing keys will be rejected with 401 Unauthorized.

**Use case**: Public endpoints where you want to restrict access.

#### 3. Client Compatibility Mode

```bash
REQUIRE_API_KEY=false
IGNORE_INCOMING_API_KEY=true
API_KEY=your-secret-key
```

Useful when your client requires an API key but you want to use the router's key instead. The client can send any dummy key, and the router will use the real key from environment variables.

**Use case**: When clients require an API key field but you want centralized key management.

## API Endpoints

### POST /v1/embeddings

OpenAI-compatible embeddings endpoint.

**Request**:

```json
{
  "model": "nomic-embed-text",
  "input": "text to embed"
}
```

Or with multiple inputs:

```json
{
  "model": "nomic-embed-text",
  "input": ["text1", "text2", "text3"]
}
```

**Response**:

```json
{
  "object": "list",
  "model": "nomic-embed-text",
  "data": [
    {
      "object": "embedding",
      "index": 0,
      "embedding": [0.123, -0.456, ...]
    }
  ]
}
```

### GET /health

Health check endpoint for container orchestration.

**Response**:

```json
{
  "ok": true,
  "provider": "ollama"
}
```

### GET /

Root endpoint for basic connectivity test.

**Response**:

```
Open Embed Router: OK
```

### Proxy Endpoints - `/api/*` and `/v1/*`

The router transparently proxies all requests to matching paths on the provider API:

- **`/api/*`** → `{PROVIDER_BASE_URL}/api/*`
- **`/v1/*`** → `{PROVIDER_BASE_URL}/v1/*` (except `/v1/embeddings` which has custom handling)

This allows using the router as a transparent proxy for any provider API endpoint.

Headers, query parameters, and request bodies are forwarded transparently.

## Kilo Code Integration

Configure Kilo Code to use the router with your preferred provider.

**Workspace settings** (`.vscode/settings.json`):

**For Ollama:**

```json
{
  "kilo-code.embedder": {
    "provider": "openai",
    "baseUrl": "http://localhost:9000/v1",
    "model": "nomic-embed-text",
    "dimensions": 768
  }
}
```

**For OpenAI/NanoGPT:**

```json
{
  "kilo-code.embedder": {
    "provider": "openai",
    "baseUrl": "http://localhost:9000/v1",
    "model": "text-embedding-3-small",
    "dimensions": 1536
  }
}
```

For HTTPS deployment:

```json
{
  "kilo-code.embedder": {
    "provider": "openai",
    "baseUrl": "https://your-domain.com/v1",
    "model": "nomic-embed-text",
    "dimensions": 768
  }
}
```

**Note**: Do not set the API key in Kilo Code settings. The router handles authentication via the `API_KEY` environment variable set in the Docker container. This keeps your API key secure and centralized in one location.

## Logging

The router uses Winston for production-grade logging with daily rotation.

### Log Files

- **`logs/combined-YYYY-MM-DD.log`** - All logs (retained for 14 days)
- **`logs/error-YYYY-MM-DD.log`** - Error logs only (retained for 30 days)

### Log Levels

- `error` - Critical errors, failed requests after retries
- `warn` - Warnings, startup check failures, retryable errors
- `info` - Request/response info, startup messages (default)
- `debug` - Detailed debugging info, retry attempts

### Viewing Logs

**Docker logs** (console output):

```bash
docker compose logs -f open-embed-router
```

**File logs** (persistent):

```bash
tail -f logs/combined-$(date +%Y-%m-%d).log
tail -f logs/error-$(date +%Y-%m-%d).log
```

## Deployment Scenarios

### Local Development

Use basic `docker-compose.yml` for local testing:

```bash
docker compose up --build
```

Access at `http://localhost:9000`

### Production with HTTPS

Use `docker-compose.https.yml` with nginx for SSL termination:

```bash
docker compose -f docker-compose.https.yml up --build
```

See [`DEPLOYMENT.md`](DEPLOYMENT.md) for SSL certificate setup.

### Cloudflare Tunnel (Free HTTPS)

The easiest way to expose your router with trusted HTTPS - completely free and no server needed.

**Why use Cloudflare Tunnel?**

- ✅ **Free trusted HTTPS** - Works with any client (no self-signed cert issues)
- ✅ **No port forwarding** - Secure tunnel, no exposed ports
- ✅ **Persistent URL** - Doesn't change on restart
- ✅ **Fully containerized** - Runs in Docker alongside your router

**Quick Setup:**

1. **Get Cloudflare token** (one-time):

   ```bash
   # Download cloudflared: https://github.com/cloudflare/cloudflared/releases
   cloudflared tunnel login
   cloudflared tunnel create open-embed-router
   cloudflared tunnel token open-embed-router
   ```

2. **Configure `.env`**:

   ```bash
   PROVIDER=ollama
   PROVIDER_BASE_URL=http://host.docker.internal:11434
   CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoi...
   ```

3. **Start services**:

   ```bash
   docker compose up -d
   ```

4. **Configure tunnel routing** at [Cloudflare Dashboard](https://dash.teams.cloudflare.com/):
   - **Public Hostname**: `embeddings.yourdomain.com`
   - **Service**: `http://open-embed-router:9000`

5. **Configure Kilo Code**:
   ```json
   {
     "kilo-code.embedder": {
       "provider": "openai",
       "baseUrl": "https://embeddings.yourdomain.com/v1",
       "model": "nomic-embed-text",
       "dimensions": 768
     }
   }
   ```

The cloudflared service is included in the default `docker-compose.yml` and will automatically start when you set `CLOUDFLARE_TUNNEL_TOKEN`.

### Cloud Deployment

The router can be deployed to any cloud provider that supports Docker:

- **AWS**: ECS, Fargate, EC2
- **GCP**: Cloud Run, GCE, GKE
- **Azure**: Container Instances, AKS
- **DigitalOcean**: App Platform, Droplets

See [`DEPLOYMENT.md`](DEPLOYMENT.md) for cloud-specific guides.

## Troubleshooting

### Startup health check fails

**Symptoms**: Warning in logs about health check failure

**Solutions**:

1. Verify your provider is running (e.g., Ollama server is started)
2. Check `PROVIDER_BASE_URL` is correct
3. Verify `API_KEY` is correct (if required by provider)
4. Check firewall rules
5. Disable health check temporarily: `STARTUP_CHECK=false`

### 502 errors on all requests

**Symptoms**: All requests return 502 Bad Gateway

**Solutions**:

1. Check provider is running and accessible
2. Verify provider URL and API key
3. Check logs for detailed error messages: `docker compose logs open-embed-router`
4. Test provider directly with curl

### Slow response times

**Symptoms**: Requests take longer than expected

**Solutions**:

1. Check provider latency
2. Reduce batch size (fewer inputs per request)
3. Check network connectivity
4. Review logs for retry attempts

### Container health check failing

**Symptoms**: Container marked unhealthy by Docker

**Solutions**:

1. Check container logs: `docker compose logs open-embed-router`
2. Verify port 9000 is not in use: `netstat -an | grep 9000`
3. Restart container: `docker compose restart open-embed-router`
4. Check for application errors in logs

## Development

### Project Structure

```
open-embed-router/
├── src/
│   └── index.js              # Main application
├── nginx/
│   ├── nginx.conf            # nginx configuration
│   └── ssl/                  # SSL certificates (gitignored)
├── logs/                     # Log files (gitignored)
├── scripts/                  # Helper scripts
├── examples/                 # Example files
├── package.json              # Node.js dependencies
├── Dockerfile                # Container definition
├── docker-compose.yml        # Basic deployment
├── docker-compose.https.yml  # HTTPS deployment
├── .env.example              # Environment template
├── .gitignore                # Git exclusions
├── README.md                 # This file
└── DEPLOYMENT.md             # Deployment guide
```

### Running Locally (without Docker)

```bash
npm install
cp .env.example .env
# Edit .env with your provider configuration
npm start
```

### Testing

**Single input (Ollama)**:

```bash
curl -X POST http://localhost:9000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "nomic-embed-text", "input": "test"}'
```

**Batched inputs**:

```bash
curl -X POST http://localhost:9000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "nomic-embed-text", "input": ["test1", "test2", "test3"]}'
```

**Health check**:

```bash
curl http://localhost:9000/health
```

## Architecture

The router processes requests sequentially to avoid provider token aggregation issues:

1. Receive OpenAI-style request with `input` array or string
2. Normalize to array of strings
3. Extract authentication headers (incoming or env)
4. Determine provider endpoint (Ollama: `/api/embed`, OpenAI: `/api/v1/embeddings`)
5. For each input string:
   - Call provider embeddings endpoint
   - Retry on transient errors (up to `ROUTER_ATTEMPTS`)
   - Parse response (handles multiple formats including Ollama and OpenAI)
   - Collect embedding vector
6. Return OpenAI-compatible response with all embeddings
7. On any failure after retries, return 502 error

## Supported Response Formats

The router automatically handles multiple embedding response formats:

| Format                                 | Example Provider       |
| -------------------------------------- | ---------------------- |
| `{ "embedding": [...] }`               | Some OpenAI-compatible |
| `{ "embeddings": [[...]] }`            | Ollama                 |
| `{ "data": [{ "embedding": [...] }] }` | OpenAI                 |
| `{ "data": [{ "vector": [...] }] }`    | Some providers         |
| `{ "vector": [...] }`                  | Some providers         |
| `{ "output": { "embedding": [...] } }` | Some providers         |

## Security

- **Never commit `.env` file** - Contains sensitive API keys
- **Use HTTPS in production** - Encrypt data in transit
- **Rotate API keys regularly** - Minimize exposure risk
- **Use secrets management** - For cloud deployments
- **Review logs carefully** - Ensure no sensitive data is logged

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

- **Documentation**: See project documentation files
- **Issues**: Report bugs and request features via GitHub issues
- **Deployment**: See [`DEPLOYMENT.md`](DEPLOYMENT.md) for production setup
- **Docker Desktop**: See [`README-DOCKER-DESKTOP.md`](README-DOCKER-DESKTOP.md) for UI-based setup
- **Model Switching**: See [`MODEL-SWITCHING.md`](MODEL-SWITCHING.md) for changing embedding models

## Acknowledgments

- Built for seamless integration with embedding clients
- Supports [Ollama](https://ollama.com) for local embeddings
- Compatible with [OpenAI](https://openai.com), [NanoGPT](https://nano-gpt.com), and more
- Inspired by OpenAI API compatibility standards

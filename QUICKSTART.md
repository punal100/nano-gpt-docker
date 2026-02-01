# Quick Start Guide

Get the Open Embed Router running in 5 minutes.

## Prerequisites

- Docker and Docker Compose installed
- An embedding provider (Ollama, OpenAI, NanoGPT, etc.)

## Step 1: Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd open-embed-router

# Copy environment template
cp .env.example .env
```

## Step 2: Configure Your Provider

Edit `.env` and set your provider:

### For Ollama (Local - Recommended for getting started)

```bash
PROVIDER=ollama
PROVIDER_BASE_URL=http://host.docker.internal:11434
TEST_MODEL=nomic-embed-text
```

Make sure Ollama is running with an embedding model:

```bash
ollama pull nomic-embed-text
ollama serve
```

### For OpenAI

```bash
PROVIDER=openai
PROVIDER_BASE_URL=https://api.openai.com
API_KEY=sk-your-openai-key-here
TEST_MODEL=text-embedding-3-small
```

### For NanoGPT

```bash
PROVIDER=openai
PROVIDER_BASE_URL=https://nano-gpt.com
API_KEY=sk-nano-your-key-here
TEST_MODEL=Qwen/Qwen3-Embedding-0.6B
```

## Step 3: Start the Router

```bash
docker compose up --build
```

You should see:

```
✓ Container open-embed-router  Started
open-embed-router  | 2026-02-01 12:00:00 info: Starting Open Embed Router
open-embed-router  | 2026-02-01 12:00:00 info: Performing startup health check...
open-embed-router  | 2026-02-01 12:00:01 info: Startup health check passed
open-embed-router  | 2026-02-01 12:00:01 info: Open Embed Router listening on 9000
```

## Step 4: Test the Router

In a new terminal:

```bash
# Health check
curl http://localhost:9000/health
# {"ok":true,"provider":"ollama"}

# Test embedding (Ollama)
curl -X POST http://localhost:9000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "nomic-embed-text", "input": "Hello world"}'
```

## Step 5: Configure Kilo Code

Add to your `.vscode/settings.json`:

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

## Done! 🎉

Your Open Embed Router is now running and ready to use.

## Next Steps

- **View logs**: `docker compose logs -f open-embed-router`
- **Stop router**: `docker compose down`
- **Restart router**: `docker compose restart`
- **Production setup**: See [`DEPLOYMENT.md`](DEPLOYMENT.md) for HTTPS configuration

## Troubleshooting

### Startup health check fails

Check your provider is running:

```bash
# For Ollama
curl http://localhost:11434/api/tags
```

### Port 9000 already in use

Change the port in `.env`:

```bash
PORT=9001
```

### Can't connect to Ollama from Docker

Make sure you're using `host.docker.internal:11434` instead of `localhost:11434`

Then restart:

```bash
docker compose down
docker compose up -d
```

### Can't connect to NanoGPT

Check your internet connection and firewall settings. Test NanoGPT directly:

```bash
curl https://nano-gpt.com/api/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "x-api-key: sk-nano-your-key" \
  -d '{"model": "Qwen/Qwen3-Embedding-0.6B", "input": "test"}'
```

## More Information

- **Full documentation**: [`README.md`](README.md)
- **Deployment guide**: [`DEPLOYMENT.md`](DEPLOYMENT.md)
- **Architecture**: [`plans/architecture.md`](plans/architecture.md)
- **API specification**: [`plans/technical-specification.md`](plans/technical-specification.md)

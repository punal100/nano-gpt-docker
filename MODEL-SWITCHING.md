# Model Switching Guide

This guide explains how to switch between different embedding models in Open Embed Router.

## Understanding Model Selection

Open Embed Router supports **any model** that your configured provider offers. The model is specified **per request**, not as a configuration setting. This means:

- You can use different models for different requests
- No need to restart the container to change models
- The client (Kilo Code) specifies which model to use

## Available Models by Provider

### Ollama (Local)

| Model                    | Dimensions | Speed     | Quality | Use Case          |
| ------------------------ | ---------- | --------- | ------- | ----------------- |
| `nomic-embed-text`       | 768        | Fast      | Good    | General purpose   |
| `mxbai-embed-large`      | 1024       | Medium    | Better  | Higher quality    |
| `all-minilm`             | 384        | Very Fast | Basic   | Quick indexing    |
| `snowflake-arctic-embed` | 1024       | Medium    | Good    | Technical content |

**Install models with:** `ollama pull nomic-embed-text`

### OpenAI

| Model                    | Dimensions | Speed  | Quality | Use Case        |
| ------------------------ | ---------- | ------ | ------- | --------------- |
| `text-embedding-3-small` | 1536       | Fast   | Good    | Cost-effective  |
| `text-embedding-3-large` | 3072       | Medium | Best    | Maximum quality |
| `text-embedding-ada-002` | 1536       | Fast   | Good    | Legacy model    |

### NanoGPT

| Model                       | Dimensions | Speed  | Quality | Use Case        |
| --------------------------- | ---------- | ------ | ------- | --------------- |
| `Qwen/Qwen3-Embedding-0.6B` | 1024       | Fast   | Good    | General purpose |
| `Qwen/Qwen3-Embedding-1.5B` | 1536       | Medium | Better  | Higher quality  |
| `Qwen/Qwen3-Embedding-3B`   | 2048       | Slower | Best    | Maximum quality |

### Together AI

| Model                                       | Dimensions | Speed | Quality | Use Case        |
| ------------------------------------------- | ---------- | ----- | ------- | --------------- |
| `togethercomputer/m2-bert-80M-8k-retrieval` | 768        | Fast  | Good    | General purpose |

## Method 1: Switch Models in Kilo Code (Recommended)

Since Kilo Code is the client making requests to the router, you configure the model in Kilo Code's settings:

### Option A: VS Code Settings UI

1. Open VS Code
2. Press `Ctrl/Cmd + ,` to open Settings
3. Search for "kilo-code embedder"
4. Find **Kilo-code › Embedder: Model**
5. Change the model name:
   - For Ollama: `nomic-embed-text`
   - For OpenAI: `text-embedding-3-small`

### Option B: Edit settings.json Directly

1. Open `.vscode/settings.json` in your workspace
2. Change the `model` field:

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

**For OpenAI:**

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

3. Save the file - Kilo Code will use the new model immediately

### Option C: Using VS Code Command Palette

1. Press `Ctrl/Cmd + Shift + P`
2. Type "Preferences: Open Workspace Settings (JSON)"
3. Edit the model field as shown above

## Method 2: Test Different Models with curl

You can test any model directly without changing configuration:

**For Ollama:**

```bash
curl -X POST http://localhost:9000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "nomic-embed-text", "input": "test"}'

curl -X POST http://localhost:9000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "mxbai-embed-large", "input": "test"}'
```

**For OpenAI:**

```bash
curl -X POST http://localhost:9000/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"model": "text-embedding-3-small", "input": "test"}'
```

## Method 3: Multiple Kilo Code Workspaces

If you need to use different models for different projects:

1. Create separate workspace folders
2. Each folder has its own `.vscode/settings.json`
3. Configure different models in each workspace

Example structure:

```
project-fast/
├── .vscode/
│   └── settings.json  # Uses nomic-embed-text (768 dims)
└── ...

project-quality/
├── .vscode/
│   └── settings.json  # Uses mxbai-embed-large (1024 dims)
└── ...
```

## Method 4: Environment Variable (Default Model)

You can set a default model that the router uses for health checks:

### Using Docker Desktop UI:

1. Stop the current container
2. Create a new container
3. In **Environment Variables**, add:
   - Variable: `TEST_MODEL`
   - Value: `nomic-embed-text`

### Using docker-compose.yml:

```yaml
environment:
  - TEST_MODEL=nomic-embed-text
```

### Using command line:

```bash
docker run -e TEST_MODEL=nomic-embed-text -p 9000:9000 open-embed-router
```

**Note**: This only affects the startup health check. The actual model used is determined by each request.

## Quick Model Comparison Script

Create a script to compare models:

```bash
#!/bin/bash
# compare-models.sh

TEXT="This is a test sentence for embedding comparison."

echo "Testing different embedding models..."
echo ""

for MODEL in "nomic-embed-text" "mxbai-embed-large"; do
    echo "Model: $MODEL"
    START=$(date +%s%N)

    RESPONSE=$(curl -s -X POST http://localhost:9000/v1/embeddings \
      -H "Content-Type: application/json" \
      -d "{\"model\": \"$MODEL\", \"input\": \"$TEXT\"}")

    END=$(date +%s%N)
    DURATION=$(( (END - START) / 1000000 ))

    # Extract dimensions
    DIMS=$(echo $RESPONSE | grep -o '"embedding":\[[^]]*\]' | head -1 | tr ',' '\n' | wc -l)

    echo "  Dimensions: $DIMS"
    echo "  Time: ${DURATION}ms"
    echo ""
done
```

## Model Selection Best Practices

### For Development/Testing

- Use `nomic-embed-text` (768 dimensions) with Ollama
- Free, fast, and good enough for most use cases
- Runs locally

### For Production (Cloud)

- Consider `text-embedding-3-small` (1536 dimensions) with OpenAI
- Reliable cloud infrastructure
- Good balance of speed and quality

### For High-Quality Needs

- Use `text-embedding-3-large` (3072 dimensions) with OpenAI
- Or `mxbai-embed-large` (1024 dimensions) with Ollama
- Best quality embeddings

### When to Switch Models

**Switch to a larger model when:**

- You need better semantic search results
- Accuracy is more important than speed
- Working with complex domain-specific content

**Switch to a smaller model when:**

- Speed is critical
- You have cost constraints
- Doing initial development/testing
- Working with simple content

## Switching Providers

If you need to switch from one provider to another (e.g., Ollama to OpenAI):

1. Update your `.env` file:

```bash
PROVIDER=openai
PROVIDER_BASE_URL=https://api.openai.com
API_KEY=sk-your-key
TEST_MODEL=text-embedding-3-small
```

2. Restart the container:

```bash
docker compose down
docker compose up -d
```

3. Update Kilo Code settings with the new model and dimensions:

```json
{
  "kilo-code.embedder": {
    "model": "text-embedding-3-small",
    "dimensions": 1536
  }
}
```

## Troubleshooting Model Issues

### "Model not found" error

- Verify the model name is correct for your provider
- For Ollama: run `ollama list` to see installed models
- For OpenAI: check the OpenAI documentation
- For Ollama: install with `ollama pull model-name`

### Dimension mismatch in Kilo Code

- Make sure `dimensions` in settings.json matches the model
- Check the model's documentation for exact dimension count

**Common dimensions:**
| Model | Dimensions |
|-------|-----------|
| nomic-embed-text | 768 |
| mxbai-embed-large | 1024 |
| all-minilm | 384 |
| text-embedding-3-small | 1536 |
| text-embedding-3-large | 3072 |
| Qwen/Qwen3-Embedding-0.6B | 1024 |
| Qwen/Qwen3-Embedding-1.5B | 1536 |

### Slow performance

- Larger models take longer
- Consider using smaller models for faster results
- For Ollama: ensure sufficient GPU memory
- For cloud providers: check network latency

## Summary

Open Embed Router is **model-agnostic** - it forwards whatever model you specify in the request to your configured provider. The easiest way to switch models is to change the `model` field in your Kilo Code settings (`.vscode/settings.json`).

No container restart or reconfiguration needed - just change the model name and Kilo Code will use the new model immediately!

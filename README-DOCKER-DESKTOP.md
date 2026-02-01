# Docker Desktop Setup Guide

This guide explains how to run the Open Embed Router using Docker Desktop's UI.

## Method 1: Using Docker Desktop UI (Recommended for Beginners)

### Step 1: Build the Image

1. Open **Docker Desktop**
2. Click on **Images** in the left sidebar
3. Click **Build** button (or use the terminal)
4. Select the folder containing the Dockerfile
5. Tag the image: `open-embed-router`
6. Click **Build**

### Step 2: Run the Container with Environment Variables

1. In Docker Desktop, go to **Images**
2. Find `open-embed-router` and click **Run**
3. Click the dropdown arrow next to **Run** and select **Optional settings**
4. Configure the following:

#### Container Settings:

- **Container name**: `open-embed-router`
- **Ports**:
  - Host port: `9000`
  - Container port: `9000`

#### Environment Variables (Required):

Click **+ Add environment variable** and add:

| Variable            | Value                               | Description                  |
| ------------------- | ----------------------------------- | ---------------------------- |
| `PROVIDER`          | `ollama` or `openai`                | **Required** - Provider type |
| `PROVIDER_BASE_URL` | `http://host.docker.internal:11434` | **Required** - Provider URL  |

#### Environment Variables (Optional):

| Variable                  | Value              | Description                       |
| ------------------------- | ------------------ | --------------------------------- |
| `API_KEY`                 | `sk-...`           | API key (not needed for Ollama)   |
| `TEST_MODEL`              | `nomic-embed-text` | Model for health check            |
| `LOG_LEVEL`               | `info`             | Log level (error/warn/info/debug) |
| `ROUTER_ATTEMPTS`         | `3`                | Retry attempts                    |
| `ROUTER_BACKOFF_MS`       | `500`              | Backoff delay in ms               |
| `STARTUP_CHECK`           | `true`             | Enable startup health check       |
| `IGNORE_INCOMING_API_KEY` | `false`            | Ignore client's API key           |

#### Provider-specific Configuration:

**For Ollama:**

- `PROVIDER`: `ollama`
- `PROVIDER_BASE_URL`: `http://host.docker.internal:11434`
- `TEST_MODEL`: `nomic-embed-text`

**For OpenAI:**

- `PROVIDER`: `openai`
- `PROVIDER_BASE_URL`: `https://api.openai.com`
- `API_KEY`: Your OpenAI key
- `TEST_MODEL`: `text-embedding-3-small`

5. Click **Run**

### Step 3: Verify It's Working

1. In Docker Desktop, click on **Containers**
2. Find `open-embed-router` - it should show as **Running**
3. Click on the container name to view logs
4. You should see:
   ```
   info: Starting Open Embed Router
   info: Startup health check passed
   info: Open Embed Router listening on 9000
   ```

### Step 4: Test the Endpoint

Open a browser or terminal and test:

```bash
curl http://localhost:9000/health
```

Or visit: `http://localhost:9000/health` in your browser

You should see: `{"ok":true,"provider":"ollama"}`

## Method 2: Using Docker Desktop Terminal

If you prefer using commands within Docker Desktop:

1. Open Docker Desktop
2. Click on the **Terminal** icon (top right)
3. Run:

```bash
# Build the image
docker build -t open-embed-router .

# Run with Ollama
docker run -d \
  --name open-embed-router \
  -p 9000:9000 \
  -e PROVIDER=ollama \
  -e PROVIDER_BASE_URL=http://host.docker.internal:11434 \
  -e TEST_MODEL=nomic-embed-text \
  --add-host=host.docker.internal:host-gateway \
  open-embed-router

# Or run with OpenAI
docker run -d \
  --name open-embed-router \
  -p 9000:9000 \
  -e PROVIDER=openai \
  -e PROVIDER_BASE_URL=https://api.openai.com \
  -e API_KEY=sk-your-key-here \
  -e TEST_MODEL=text-embedding-3-small \
  open-embed-router
```

## Method 3: Import Pre-built Image

If someone shared the image with you:

1. In Docker Desktop, go to **Images**
2. Click **Import** (or drag and drop the .tar file)
3. Once imported, follow Step 2 above to run it

## Viewing Logs in Docker Desktop

1. Click on **Containers** in the left sidebar
2. Click on `open-embed-router`
3. Click on **Logs** tab

You'll see real-time logs including:

- Request processing
- Health check status
- Any errors or warnings

## Stopping the Container

1. In Docker Desktop, go to **Containers**
2. Find `open-embed-router`
3. Click the **Stop** button (square icon)

Or click the **Delete** button (trash icon) to remove it completely.

## Updating Environment Variables

If you need to change the provider or other settings:

1. Stop and delete the current container
2. Create a new container with the updated environment variables
3. Or use Docker Compose (see below)

## Using Docker Compose in Docker Desktop

Docker Desktop has built-in Compose support:

1. Create a `.env` file in the project folder:

```
PROVIDER=ollama
PROVIDER_BASE_URL=http://host.docker.internal:11434
TEST_MODEL=nomic-embed-text
```

2. In Docker Desktop terminal, run:

```bash
docker compose up -d
```

3. To stop:

```bash
docker compose down
```

## Troubleshooting in Docker Desktop

### Container won't start

- Check the **Logs** tab for error messages
- Verify `PROVIDER_BASE_URL` is set correctly
- Ensure port 9000 is not already in use

### Can't connect to router

- Verify the container is **Running** (green dot)
- Check port mapping: Host 9000 → Container 9000
- Test with: `curl http://localhost:9000/health`

### Can't connect to Ollama

- Use `http://host.docker.internal:11434` instead of `localhost`
- Make sure Ollama is running on your host machine

### Health check fails

- Verify your provider is running and accessible
- Check that the TEST_MODEL exists
- Review logs for specific error messages

## Tips for Docker Desktop

1. **Auto-start**: Enable "Start Docker Desktop when you log in" for convenience
2. **Resource limits**: Adjust CPU/Memory in Settings → Resources if needed
3. **Updates**: Keep Docker Desktop updated for latest features
4. **Volumes**: Logs are stored in a Docker volume - access via container logs

## Next Steps

Once running, configure Kilo Code:

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

For more details, see the main [README.md](README.md).

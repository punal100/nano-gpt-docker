#!/bin/bash
# Example curl commands for testing the Open Embed Router

# Configuration
BASE_URL="${BASE_URL:-http://localhost:9000}"
API_KEY="${API_KEY:-}"
MODEL="${MODEL:-nomic-embed-text}"

echo "=== Open Embed Router - Example Requests ==="
echo ""
echo "Base URL: $BASE_URL"
echo "Model: $MODEL"
echo ""

# Health check
echo "1. Health check:"
echo "curl $BASE_URL/health"
echo ""
curl $BASE_URL/health
echo ""
echo ""

# Root endpoint
echo "2. Root endpoint:"
echo "curl $BASE_URL/"
echo ""
curl $BASE_URL/
echo ""
echo ""

# Single input embedding
echo "3. Single input embedding:"
echo "curl -X POST $BASE_URL/v1/embeddings \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"model\": \"$MODEL\", \"input\": \"Hello world\"}'"
echo ""
curl -X POST $BASE_URL/v1/embeddings \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"$MODEL\", \"input\": \"Hello world\"}"
echo ""
echo ""

# Batched input embedding
echo "4. Batched input embedding:"
echo "curl -X POST $BASE_URL/v1/embeddings \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"model\": \"$MODEL\", \"input\": [\"text1\", \"text2\"]}'"
echo ""
curl -X POST $BASE_URL/v1/embeddings \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"$MODEL\", \"input\": [\"text1\", \"text2\"]}"
echo ""
echo ""

# Using Authorization header (for providers that need it)
echo "5. With Authorization header (if API_KEY is set):"
if [ -n "$API_KEY" ]; then
  echo "curl -X POST $BASE_URL/v1/embeddings \\"
  echo "  -H \"Content-Type: application/json\" \\"
  echo "  -H \"Authorization: Bearer \$API_KEY\" \\"
  echo "  -d '{\"model\": \"$MODEL\", \"input\": \"Test\"}'"
  echo ""
  curl -X POST $BASE_URL/v1/embeddings \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "{\"model\": \"$MODEL\", \"input\": \"Test\"}"
else
  echo "(Skipped - no API_KEY set)"
fi
echo ""
echo ""

echo "=== Examples Complete ==="
echo ""
echo "To run with custom settings:"
echo "  BASE_URL=https://your-domain.com MODEL=text-embedding-3-small API_KEY=sk-xxx ./examples/test-request.sh"
echo ""
echo "Provider Examples:"
echo "  Ollama:  MODEL=nomic-embed-text ./examples/test-request.sh"
echo "  OpenAI:  MODEL=text-embedding-3-small API_KEY=sk-xxx ./examples/test-request.sh"
echo "  NanoGPT: MODEL=Qwen/Qwen3-Embedding-0.6B API_KEY=sk-nano-xxx ./examples/test-request.sh"
echo ""

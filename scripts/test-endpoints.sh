#!/bin/bash
# Test NanoGPT shim endpoints
# Usage: ./test-endpoints.sh [base-url] [api-key]

set -e

# Configuration
BASE_URL="${1:-http://localhost:9000}"
API_KEY="${2:-}"
MODEL="Qwen/Qwen3-Embedding-0.6B"

echo "=== NanoGPT Shim - Endpoint Testing ==="
echo ""
echo "Base URL: $BASE_URL"
echo "Model: $MODEL"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

# Function to make API request
api_request() {
    local endpoint=$1
    local method=$2
    local data=$3
    local headers=$4
    
    if [ "$method" = "GET" ]; then
        curl -s -w "\n%{http_code}" "$BASE_URL$endpoint" $headers
    else
        curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            $headers \
            -d "$data"
    fi
}

echo "Running tests..."
echo ""

# Test 1: Health check
echo "Test 1: Health check endpoint"
RESPONSE=$(api_request "/health" "GET")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q '"ok":true'; then
    print_result 0 "Health check returned 200 OK"
else
    print_result 1 "Health check failed (HTTP $HTTP_CODE)"
fi
echo ""

# Test 2: Root endpoint
echo "Test 2: Root endpoint"
RESPONSE=$(api_request "/" "GET")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q "NanoGPT shim"; then
    print_result 0 "Root endpoint returned 200 OK"
else
    print_result 1 "Root endpoint failed (HTTP $HTTP_CODE)"
fi
echo ""

# Test 3: Single input embedding (requires API key)
if [ -n "$API_KEY" ]; then
    echo "Test 3: Single input embedding"
    DATA='{"model":"'$MODEL'","input":"Hello world"}'
    HEADERS="-H \"x-api-key: $API_KEY\""
    RESPONSE=$(api_request "/v1/embeddings" "POST" "$DATA" "$HEADERS")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)
    
    if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q '"embedding"'; then
        print_result 0 "Single input embedding successful"
        # Check embedding dimensions
        DIMS=$(echo "$BODY" | grep -o '"embedding":\[[^]]*\]' | grep -o ',' | wc -l)
        echo "  Embedding dimensions: $((DIMS + 1))"
    else
        print_result 1 "Single input embedding failed (HTTP $HTTP_CODE)"
        echo "  Response: $BODY"
    fi
    echo ""
    
    # Test 4: Batched input embedding
    echo "Test 4: Batched input embedding"
    DATA='{"model":"'$MODEL'","input":["Hello","World","Test"]}'
    RESPONSE=$(api_request "/v1/embeddings" "POST" "$DATA" "$HEADERS")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)
    
    if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q '"data"'; then
        COUNT=$(echo "$BODY" | grep -o '"index":[0-9]*' | wc -l)
        if [ "$COUNT" -eq 3 ]; then
            print_result 0 "Batched input embedding successful (3 embeddings)"
        else
            print_result 1 "Batched input embedding returned wrong count ($COUNT)"
        fi
    else
        print_result 1 "Batched input embedding failed (HTTP $HTTP_CODE)"
        echo "  Response: $BODY"
    fi
    echo ""
    
    # Test 5: Error handling - missing model
    echo "Test 5: Error handling - missing model"
    DATA='{"input":"test"}'
    RESPONSE=$(api_request "/v1/embeddings" "POST" "$DATA" "$HEADERS")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)
    
    if [ "$HTTP_CODE" = "400" ] && echo "$BODY" | grep -q '"error"'; then
        print_result 0 "Missing model returns 400 error"
    else
        print_result 1 "Missing model error handling failed (HTTP $HTTP_CODE)"
    fi
    echo ""
    
    # Test 6: Error handling - missing input
    echo "Test 6: Error handling - missing input"
    DATA='{"model":"'$MODEL'"}'
    RESPONSE=$(api_request "/v1/embeddings" "POST" "$DATA" "$HEADERS")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)
    
    if [ "$HTTP_CODE" = "400" ] && echo "$BODY" | grep -q '"error"'; then
        print_result 0 "Missing input returns 400 error"
    else
        print_result 1 "Missing input error handling failed (HTTP $HTTP_CODE)"
    fi
    echo ""
else
    echo -e "${YELLOW}Skipping embedding tests (no API key provided)${NC}"
    echo "Usage: $0 [base-url] [api-key]"
    echo ""
fi

# Test 7: Response time
echo "Test 7: Response time"
START=$(date +%s%N)
RESPONSE=$(api_request "/health" "GET")
END=$(date +%s%N)
DURATION=$(( (END - START) / 1000000 ))

if [ $DURATION -lt 1000 ]; then
    print_result 0 "Response time acceptable (${DURATION}ms)"
else
    print_result 1 "Response time slow (${DURATION}ms)"
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo ""
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi

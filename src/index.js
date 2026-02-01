// index.js - Open Embed Router - Provider-agnostic embeddings router
import express from "express";
import winston from "winston";
import DailyRotateFile from "winston-daily-rotate-file";

const app = express();
app.use(express.json());

// Configuration from environment
const PROVIDER = (process.env.PROVIDER || "openai").toLowerCase(); // "openai" or "ollama"
const PROVIDER_BASE_URL = process.env.PROVIDER_BASE_URL || "http://localhost:11434";
const API_KEY = process.env.API_KEY || "";
const DEFAULT_PAYMENT = process.env.X_PAYMENT || "";
const ATTEMPTS = parseInt(process.env.ROUTER_ATTEMPTS || "3", 10);
const BACKOFF_MS = parseInt(process.env.ROUTER_BACKOFF_MS || "500", 10);
const PORT = parseInt(process.env.PORT || "9000", 10);
const LOG_LEVEL = process.env.LOG_LEVEL || "info";
const LOG_DIR = process.env.LOG_DIR || "/app/logs";
const STARTUP_CHECK = process.env.STARTUP_CHECK !== "false";
const IGNORE_INCOMING_API_KEY = process.env.IGNORE_INCOMING_API_KEY === "true"; // Option to require API key validation
const REQUIRE_API_KEY = process.env.REQUIRE_API_KEY === "true"; // Option: require API key authentication

// Configure Winston logger
const logFormat = winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
);

const logger = winston.createLogger({
    level: LOG_LEVEL,
    format: logFormat,
    transports: [
        // Console transport for Docker logs
        new winston.transports.Console({
            format: winston.format.combine(
                winston.format.colorize(),
                winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss" }),
                winston.format.printf(({ timestamp, level, message, ...meta }) => {
                    const metaStr = Object.keys(meta).length ? JSON.stringify(meta) : "";
                    return `${timestamp} ${level}: ${message} ${metaStr}`;
                })
            ),
        }),
        // Daily rotate file for all logs
        new DailyRotateFile({
            filename: `${LOG_DIR}/combined-%DATE%.log`,
            datePattern: "YYYY-MM-DD",
            maxSize: "20m",
            maxFiles: "14d",
            format: logFormat,
        }),
        // Daily rotate file for errors only
        new DailyRotateFile({
            filename: `${LOG_DIR}/error-%DATE%.log`,
            datePattern: "YYYY-MM-DD",
            level: "error",
            maxSize: "20m",
            maxFiles: "30d",
            format: logFormat,
        }),
    ],
});

// Simple sleep utility
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Get the embeddings endpoint URL based on provider
function getEmbeddingsUrl() {
    const base = PROVIDER_BASE_URL.replace(/\/$/, '');
    if (PROVIDER === "ollama") {
        return `${base}/api/embed`;
    }
    // OpenAI-compatible providers (default)
    return `${base}/api/v1/embeddings`;
}

// Call provider for a single input string, return embedding array
async function fetchEmbedding(model, input, headers) {
    const embeddingsUrl = getEmbeddingsUrl();
    
    for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
        try {
            // Build request body based on provider
            const body = PROVIDER === "ollama" 
                ? { model, input } 
                : { model, input };
            
            const resp = await fetch(embeddingsUrl, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    ...(headers || {}),
                },
                body: JSON.stringify(body),
            });

            const j = await resp.json().catch(() => null);

            // Non-JSON or HTTP error: treat as retryable
            if (!j) {
                logger.warn({
                    message: "Non-JSON response from embedder",
                    attempt,
                    maxAttempts: ATTEMPTS,
                    status: resp.status,
                });
                if (attempt < ATTEMPTS) {
                    await sleep(BACKOFF_MS * attempt);
                    continue;
                } else {
                    throw new Error(`embedder returned non-json (status ${resp.status})`);
                }
            }

            // If provider returned top-level error object
            if (j.error) {
                const msg = j.error?.message || JSON.stringify(j.error);
                logger.warn({
                    message: "Embedder returned error",
                    attempt,
                    maxAttempts: ATTEMPTS,
                    error: msg,
                });
                if (attempt < ATTEMPTS) {
                    await sleep(BACKOFF_MS * attempt);
                    continue;
                } else {
                    throw new Error(`embedder error: ${msg}`);
                }
            }

            // Support common response shapes:
            // 1) { "embedding": [...] }
            // 2) { "data": [ { "embedding": [...] } ] }
            // 3) { "data": [ { "vector": [...] } ] }
            // 4) { "vector": [...] }
            // 5) { "v": [...] }
            // 6) { "output": { "embedding": [...] } }
            // 7) { "embeddings": [[...]] } (Ollama format)
            let vec = null;
            if (Array.isArray(j.embedding)) vec = j.embedding;
            else if (Array.isArray(j.embeddings) && j.embeddings[0]) vec = j.embeddings[0]; // Ollama
            else if (Array.isArray(j.data) && j.data[0]) {
                if (Array.isArray(j.data[0].embedding)) vec = j.data[0].embedding;
                else if (Array.isArray(j.data[0].vector)) vec = j.data[0].vector;
            } else if (Array.isArray(j.vector)) vec = j.vector;
            else if (Array.isArray(j.v)) vec = j.v;
            else if (Array.isArray(j.output?.embedding)) vec = j.output.embedding;

            if (!Array.isArray(vec)) {
                logger.warn({
                    message: "Unexpected embedder response shape",
                    attempt,
                    maxAttempts: ATTEMPTS,
                    responseKeys: Object.keys(j),
                });
                if (attempt < ATTEMPTS) {
                    await sleep(BACKOFF_MS * attempt);
                    continue;
                } else {
                    throw new Error(
                        `unexpected embedder response shape: ${JSON.stringify(j).slice(0, 400)}`
                    );
                }
            }

            logger.debug({
                message: "Successfully fetched embedding",
                attempt,
                vectorLength: vec.length,
            });

            return vec;
        } catch (err) {
            logger.warn({
                message: "Error fetching embedding",
                attempt,
                maxAttempts: ATTEMPTS,
                error: err.message,
            });
            if (attempt < ATTEMPTS) {
                await sleep(BACKOFF_MS * attempt);
                continue;
            }
            throw err;
        }
    }
}

// Startup health check to verify provider connectivity
async function startupHealthCheck() {
    if (!STARTUP_CHECK) {
        logger.info("Startup health check disabled");
        return;
    }

    try {
        logger.info({ message: "Performing startup health check...", provider: PROVIDER });
        const testInput = "test";
        const testModel = process.env.TEST_MODEL || (PROVIDER === "ollama" ? "nomic-embed-text" : "text-embedding-ada-002");

        const headers = {};
        if (API_KEY) headers["x-api-key"] = API_KEY;
        if (DEFAULT_PAYMENT) headers["X-PAYMENT"] = DEFAULT_PAYMENT;

        const embedding = await fetchEmbedding(testModel, testInput, headers);

        if (Array.isArray(embedding) && embedding.length > 0) {
            logger.info({
                message: "Startup health check passed",
                provider: PROVIDER,
                model: testModel,
                embeddingDimensions: embedding.length,
            });
        } else {
            logger.warn("Startup health check returned invalid embedding");
        }
    } catch (err) {
        logger.warn({
            message: "Startup health check failed",
            error: err.message,
            note: "Server will start anyway, but provider may be unreachable",
        });
    }
}

// POST /v1/embeddings (OpenAI-compatible)
app.post("/v1/embeddings", async (req, res) => {
    const startTime = Date.now();
    try {
        const model = req.body.model;
        if (!model) {
            logger.warn({ message: "Request missing model parameter" });
            return res.status(400).json({ error: "model required" });
        }

        // Normalize inputs to array of strings
        const inputs = Array.isArray(req.body.input)
            ? req.body.input
            : [req.body.input];
        if (!inputs || inputs.length === 0) {
            logger.warn({ message: "Request missing input parameter" });
            return res.status(400).json({ error: "input required" });
        }

        logger.info({
            message: "Request received",
            method: "POST",
            path: "/v1/embeddings",
            model,
            inputCount: inputs.length,
        });

        // Build headers to send to NanoGPT
        const incomingApiKey =
            req.header("x-api-key") || req.header("authorization");
        const incomingPayment =
            req.header("x-payment") || req.header("X-PAYMENT");

        const headers = {};

        // API Key validation logic
        // REQUIRE_API_KEY=true: Must provide matching API key (private access)
        // REQUIRE_API_KEY=false: No API key required (public access)
        if (REQUIRE_API_KEY && API_KEY) {
            // Private mode: validate incoming key matches API_KEY
            let keyToCheck = incomingApiKey;
            if (incomingApiKey && /^Bearer\s+/i.test(incomingApiKey)) {
                keyToCheck = incomingApiKey.replace(/^Bearer\s+/i, '');
            }

            if (keyToCheck !== API_KEY) {
                logger.warn({ message: "Invalid or missing API key", ip: req.ip });
                return res.status(401).json({ error: "Unauthorized - Invalid or missing API key" });
            }

            headers["x-api-key"] = API_KEY;
            logger.debug({ message: "API key validated, using configured key" });
        } else if (IGNORE_INCOMING_API_KEY && API_KEY) {
            // Legacy mode: ignore incoming key, always use configured key
            headers["x-api-key"] = API_KEY;
            logger.debug({ message: "Using configured API key (ignoring incoming)" });
        } else if (incomingApiKey) {
            // Forward incoming key if provided
            if (
                /^Bearer\s+/i.test(incomingApiKey) ||
                /^Authorization:/i.test(incomingApiKey)
            ) {
                headers["Authorization"] = incomingApiKey;
            } else {
                headers["x-api-key"] = incomingApiKey;
            }
        } else if (API_KEY) {
            headers["x-api-key"] = API_KEY;
        }

        // Forward X-PAYMENT if present incoming or default
        if (incomingPayment) headers["X-PAYMENT"] = incomingPayment;
        else if (DEFAULT_PAYMENT) headers["X-PAYMENT"] = DEFAULT_PAYMENT;

        // Process each input sequentially to avoid NanoGPT per-request token aggregation issues
        const output = [];
        for (let i = 0; i < inputs.length; i++) {
            const text = String(inputs[i] ?? "");
            logger.debug({
                message: "Processing input",
                index: i,
                total: inputs.length,
                textLength: text.length,
            });
            const emb = await fetchEmbedding(model, text, headers);
            output.push({ object: "embedding", index: i, embedding: emb });
        }

        const duration = Date.now() - startTime;
        logger.info({
            message: "Request completed",
            status: 200,
            model,
            inputCount: inputs.length,
            duration: `${duration}ms`,
        });

        return res.json({ object: "list", model, data: output });
    } catch (err) {
        const duration = Date.now() - startTime;
        logger.error({
            message: "Request failed",
            error: err?.message || String(err),
            status: 502,
            duration: `${duration}ms`,
        });
        // Do NOT return a malformed embedding; return error status so Kilo retries
        return res
            .status(502)
            .json({ error: err?.message || "upstream embedder error" });
    }
});

// Health check endpoint
app.get("/health", (req, res) => {
    res.json({ ok: true, provider: PROVIDER });
});

// Root endpoint
app.get("/", (req, res) => {
    res.send("Open Embed Router: OK");
});

// Generic proxy function for forwarding requests to the provider
async function proxyToProvider(req, res) {
    const startTime = Date.now();
    try {
        // Build the target URL - ensure proper path joining
        // Remove trailing slash from base and leading slash from path to avoid double slashes
        const base = PROVIDER_BASE_URL.replace(/\/$/, '');
        const path = req.path.replace(/^\//, '');
        const targetUrl = `${base}/${path}`;

        logger.info({
            message: "Proxy request details",
            method: req.method,
            provider: PROVIDER,
            incomingPath: req.path,
            base,
            processedPath: path,
            targetUrl,
        });

        // Build headers to forward
        const headers = {};

        // Forward content-type if present
        const contentType = req.header("content-type");
        if (contentType) headers["Content-Type"] = contentType;

        // Forward auth headers (prefer incoming, fallback to env)
        const incomingApiKey = req.header("x-api-key") || req.header("authorization");
        const incomingPayment = req.header("x-payment") || req.header("X-PAYMENT");

        if (incomingApiKey) {
            if (/^Bearer\s+/i.test(incomingApiKey) || /^Authorization:/i.test(incomingApiKey)) {
                headers["Authorization"] = incomingApiKey;
            } else {
                headers["x-api-key"] = incomingApiKey;
            }
        } else if (API_KEY) {
            headers["x-api-key"] = API_KEY;
        }

        if (incomingPayment) headers["X-PAYMENT"] = incomingPayment;
        else if (DEFAULT_PAYMENT) headers["X-PAYMENT"] = DEFAULT_PAYMENT;

        // Forward other relevant headers
        const headersToForward = ["accept", "accept-encoding", "accept-language", "user-agent"];
        for (const h of headersToForward) {
            const val = req.header(h);
            if (val) headers[h] = val;
        }

        logger.debug({
            message: "Proxying request",
            method: req.method,
            path: req.path,
            targetUrl,
        });

        // Build fetch options
        const fetchOptions = {
            method: req.method,
            headers,
        };

        // Forward body for non-GET/HEAD requests
        if (req.method !== "GET" && req.method !== "HEAD" && req.body) {
            fetchOptions.body = JSON.stringify(req.body);
        }

        // Forward query parameters
        const queryString = new URLSearchParams(req.query).toString();
        const fullUrl = queryString ? `${targetUrl}?${queryString}` : targetUrl;

        const resp = await fetch(fullUrl, fetchOptions);

        // Get response body
        const body = await resp.text();

        // Log response details for debugging
        logger.info({
            message: "Proxy response received",
            method: req.method,
            path: req.path,
            targetUrl: fullUrl,
            status: resp.status,
            contentType: resp.headers.get("content-type"),
            bodyPreview: body.substring(0, 200), // First 200 chars for debugging
        });

        // Forward response headers
        const headersToSend = ["content-type", "content-length", "x-ratelimit-limit", "x-ratelimit-remaining"];
        for (const h of headersToSend) {
            const val = resp.headers.get(h);
            if (val) res.setHeader(h, val);
        }

        const duration = Date.now() - startTime;
        logger.info({
            message: "Proxy request completed",
            method: req.method,
            path: req.path,
            status: resp.status,
            duration: `${duration}ms`,
        });

        // Send response with the same status code
        res.status(resp.status).send(body);
    } catch (err) {
        const duration = Date.now() - startTime;
        logger.error({
            message: "Proxy request failed",
            method: req.method,
            path: req.path,
            error: err?.message || String(err),
            duration: `${duration}ms`,
        });
        res.status(502).json({ error: err?.message || "upstream proxy error" });
    }
}

// Catch-all proxy route for /api/* paths
app.all("/api/*", proxyToProvider);

// Catch-all proxy route for /v1/* paths (except /v1/embeddings which has custom handling)
app.all("/v1/*", (req, res, next) => {
    // Skip if it's the embeddings endpoint (handled separately)
    if (req.path === "/v1/embeddings" || req.path === "/v1/embeddings/") {
        return next();
    }
    return proxyToProvider(req, res);
});

// Start server
async function start() {
    logger.info("Starting Open Embed Router");
    logger.info({
        message: "Configuration",
        PORT,
        PROVIDER,
        PROVIDER_BASE_URL,
        ROUTER_ATTEMPTS: ATTEMPTS,
        ROUTER_BACKOFF_MS: BACKOFF_MS,
        LOG_LEVEL,
        LOG_DIR,
        STARTUP_CHECK,
    });

    // Run startup health check
    await startupHealthCheck();

    app.listen(PORT, () => {
        logger.info({
            message: "Open Embed Router listening",
            port: PORT,
            provider: PROVIDER,
            baseUrl: PROVIDER_BASE_URL,
        });
    });
}

start().catch((err) => {
    logger.error({ message: "Failed to start server", error: err.message });
    process.exit(1);
});

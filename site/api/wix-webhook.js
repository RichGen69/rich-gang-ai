// Wix webhook receiver for the "Rich Gang AI" Wix app
// (App ID c8f9286a-e19c-462f-ac1e-295aeebff4b7).
//
// Wix sends each webhook as an HTTP POST whose entire raw body is a
// JWT signed with RS256. We verify the signature with the app's Wix
// public key (below — a PUBLIC key, safe to ship in code), decode the
// nested payload, log the event to Vercel runtime logs, and answer 200.
// Unverified requests are rejected with 401. Nothing is stored here;
// runtime logs are the record until a store is wired.

const crypto = require("crypto");

const DEFAULT_PUBLIC_KEY = `-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnq/HYc+08XjdMiJ57TLx
kNJzADSD58R7A5LBE9GUgBUa+pY28OYhMIY4hUvkM0UuTZHFnxsEENGn7RDIixuo
NFtfkAT+u4nJvdxa7+wNzPHGyI3Qd+Cn1XLfT24143XvHAWj2I3A4tIpYB0G6Apc
SxaRrIiQKTNQ0hrabdBQDnImyGTdYqEWqvjIfsL+Vcx5FracqtDomVU5E15OznXx
W50A3nRBTWnF5gn34iOG59QtxuxQh56Uico6vic7nlf2KCNZCJhHpdRE2QH+5PHE
bZQtk984tCIoRo0bTrfqH25BIs3v3j6qMfLtTppodHQRroMyUDEpQ6aVh1f8EIlf
LwIDAQAB
-----END PUBLIC KEY-----`;

function publicKey() {
  const fromEnv = process.env.WIX_WEBHOOK_PUBLIC_KEY;
  if (fromEnv && fromEnv.includes("BEGIN PUBLIC KEY")) {
    return fromEnv.replace(/\\n/g, "\n");
  }
  return DEFAULT_PUBLIC_KEY;
}

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(Buffer.from(c)));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function base64UrlJson(part) {
  return JSON.parse(Buffer.from(part, "base64url").toString("utf8"));
}

// Returns the decoded event envelope on success, throws on any failure.
function verifyAndDecode(token) {
  const parts = token.trim().split(".");
  if (parts.length !== 3) throw new Error("not a JWT");
  const [headerB64, payloadB64, signatureB64] = parts;

  const header = base64UrlJson(headerB64);
  if (header.alg !== "RS256") throw new Error("unexpected alg: " + header.alg);

  const signed = Buffer.from(headerB64 + "." + payloadB64, "utf8");
  const signature = Buffer.from(signatureB64, "base64url");
  const ok = crypto.verify(
    "RSA-SHA256",
    signed,
    { key: publicKey(), padding: crypto.constants.RSA_PKCS1_PADDING },
    signature
  );
  if (!ok) throw new Error("signature verification failed");

  const outer = base64UrlJson(payloadB64);
  if (outer.exp && Date.now() / 1000 > outer.exp) throw new Error("token expired");

  // Outer payload: { data: "<json string>", iat, exp }.
  // Inner: { eventType, instanceId, data: "<json string>" }.
  let inner = outer;
  if (typeof outer.data === "string") {
    try { inner = JSON.parse(outer.data); } catch (_) { /* keep outer */ }
  } else if (outer.data && typeof outer.data === "object") {
    inner = outer.data;
  }
  return inner;
}

async function handler(req, res) {
  if (req.method === "GET") {
    res.status(200).json({
      ok: true,
      service: "rich-gang-ai-wix-webhook",
      accepts: "POST with a Wix-signed JWT body (RS256)",
    });
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({ error: "method not allowed" });
    return;
  }

  let raw;
  try {
    raw = await readRawBody(req);
  } catch (e) {
    res.status(400).json({ error: "could not read body" });
    return;
  }
  if (!raw || !raw.trim()) {
    res.status(400).json({ error: "empty body" });
    return;
  }

  try {
    const event = verifyAndDecode(raw);
    const eventType = event.eventType || "(unknown)";
    const instanceId = event.instanceId || "(none)";
    console.log("[wix-webhook] verified event:", eventType, "instance:", instanceId);
    res.status(200).json({ received: true, verified: true, eventType });
  } catch (e) {
    console.log("[wix-webhook] rejected unverified request:", e.message);
    res.status(401).json({ error: "invalid signature" });
  }
}

module.exports = handler;
module.exports.config = { api: { bodyParser: false } };

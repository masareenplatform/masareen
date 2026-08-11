// MASAREN realtime broadcast hub — Stage 4.
//
// A dependency-free WebSocket fan-out server (Node built-in `http` + `crypto`
// only) that relays topic messages between connected clients so the web/mobile
// feed, messenger and notifications update live across tabs AND users — no
// manual refresh. It pairs with `apps/web/src/services/realtime.ts`, whose
// protocol is:
//
//   client -> server : JSON.stringify({ topic, payload })   (text frame)
//   server -> client : JSON.stringify({ topic, payload })   (broadcast)
//
// The server broadcasts each message to EVERY OTHER client (never echoing back
// to the sender) so `realtime.publish` doesn't double-fire on the origin tab.
//
// It also exposes a REST `POST /publish` so non-WS producers (the backend, a
// cron job, the gateway) can inject events into the live graph.
//
// Run:  node ws-server.mjs            (listens on :8787 by default)
//       WS_URL=ws://localhost:8787 PORT=8787 node ws-server.mjs
//
// Wire the web client with VITE_WS_URL=ws://localhost:8787 (see .env.example).

import http from "node:http";
import crypto from "node:crypto";
import { URL } from "node:url";

const PORT = Number(process.env.PORT || process.env.WS_PORT || 8787);
const HOST = process.env.WS_HOST || "0.0.0.0";

/** @type {Set<import('node:net').Socket & { _frags?: Buffer, _fragmented?: boolean, _fragOpcode?: number, _buf?: Buffer, _alive?: boolean }>} */
const clients = new Set();

let totalConnections = 0;
const stats = { messagesRelayed: 0, restInjected: 0, startedAt: Date.now() };

function broadcast(topic, payload, except) {
  if (!topic) return;
  const frame = encodeText(JSON.stringify({ topic, payload }));
  let sent = 0;
  for (const sock of clients) {
    if (sock === except) continue;
    if (sock.readyState === "open") {
      try {
        sock.write(frame);
        sent++;
      } catch {
        /* drop silently */
      }
    }
  }
  stats.messagesRelayed++;
  return sent;
}

// ── HTTP surface: health, stats, REST publish ──────────────────────────────
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  if (req.method === "GET" && (url.pathname === "/health" || url.pathname === "/")) {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(
      JSON.stringify({
        status: "healthy",
        service: "masaren-realtime",
        clients: clients.size,
        ...stats,
        uptimeSeconds: Math.floor((Date.now() - stats.startedAt) / 1000),
      })
    );
    return;
  }

  if (req.method === "POST" && url.pathname === "/publish") {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      try {
        const { topic, payload } = JSON.parse(body || "{}");
        if (!topic) {
          res.writeHead(400, { "content-type": "application/json" });
          res.end(JSON.stringify({ success: false, error: "MISSING_TOPIC" }));
          return;
        }
        const sent = broadcast(topic, payload, null);
        stats.restInjected++;
        res.writeHead(200, { "content-type": "application/json" });
        res.end(JSON.stringify({ success: true, delivered: sent }));
      } catch (e) {
        res.writeHead(400, { "content-type": "application/json" });
        res.end(JSON.stringify({ success: false, error: "BAD_JSON" }));
      }
    });
    return;
  }

  res.writeHead(404, { "content-type": "application/json" });
  res.end(JSON.stringify({ success: false, error: "NOT_FOUND" }));
});

// ── WebSocket upgrade ──────────────────────────────────────────────────────
const GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

server.on("upgrade", (req, socket) => {
  const key = req.headers["sec-websocket-key"];
  if (!key) {
    socket.destroy();
    return;
  }
  const accept = crypto
    .createHash("sha1")
    .update(key + GUID)
    .digest("base64");

  socket.write(
    "HTTP/1.1 101 Switching Protocols\r\n" +
      "Upgrade: websocket\r\n" +
      "Connection: Upgrade\r\n" +
      `Sec-WebSocket-Accept: ${accept}\r\n\r\n`
  );

  socket._buf = Buffer.alloc(0);
  socket._frags = Buffer.alloc(0);
  socket._fragmented = false;
  socket._alive = true;
  clients.add(socket);
  totalConnections++;

  socket.on("data", (chunk) => {
    socket._buf = Buffer.concat([socket._buf, chunk]);
    try {
      parseFrames(socket);
    } catch {
      socket.destroy();
    }
  });

  socket.on("close", () => clients.delete(socket));
  socket.on("error", () => clients.delete(socket));
});

// ── Minimal RFC6455 frame codec (text only, server->client unmasked) ───────
function parseFrames(sock) {
  let buf = sock._buf;
  while (buf.length >= 2) {
    const b0 = buf[0];
    const b1 = buf[1];
    const fin = (b0 & 0x80) !== 0;
    const opcode = b0 & 0x0f;
    const masked = (b1 & 0x80) !== 0;
    let len = b1 & 0x7f;
    let offset = 2;

    if (len === 126) {
      if (buf.length < offset + 2) return needMore(buf, sock);
      len = buf.readUInt16BE(offset);
      offset += 2;
    } else if (len === 127) {
      if (buf.length < offset + 8) return needMore(buf, sock);
      const hi = buf.readUInt32BE(offset);
      const lo = buf.readUInt32BE(offset + 4);
      len = hi * 2 ** 32 + lo;
      offset += 8;
    }

    let maskKey;
    if (masked) {
      if (buf.length < offset + 4) return needMore(buf, sock);
      maskKey = buf.subarray(offset, offset + 4);
      offset += 4;
    }

    if (buf.length < offset + len) return needMore(buf, sock);

    let payload = buf.subarray(offset, offset + len);
    if (masked) {
      const out = Buffer.allocUnsafe(len);
      for (let i = 0; i < len; i++) out[i] = payload[i] ^ maskKey[i & 3];
      payload = out;
    }
    buf = buf.subarray(offset + len);
    sock._buf = buf;

    handleFrame(sock, fin, opcode, payload);
  }
}

function needMore(buf, sock) {
  sock._buf = buf; // wait for more data
}

function handleFrame(sock, fin, opcode, payload) {
  // Continuation / fragmentation reassembly (text only).
  if (opcode === 0x0) {
    sock._frags = Buffer.concat([sock._frags, payload]);
    if (fin) {
      const full = sock._frags;
      sock._frags = Buffer.alloc(0);
      sock._fragmented = false;
      dispatch(sock, sock._fragOpcode || 0x1, full);
    }
    return;
  }
  if (opcode === 0x1 || opcode === 0x2) {
    if (!fin) {
      sock._frags = Buffer.concat([sock._frags, payload]);
      sock._fragmented = true;
      sock._fragOpcode = opcode;
      return;
    }
    dispatch(sock, opcode, payload);
    return;
  }
  if (opcode === 0x8) {
    // close
    try {
      sock.write(encode(0x8, Buffer.alloc(0)));
    } catch {}
    sock.end();
    return;
  }
  if (opcode === 0x9) {
    // ping -> pong
    try {
      sock.write(encode(0xa, payload));
    } catch {}
    return;
  }
  if (opcode === 0xa) return; // pong
}

function dispatch(sock, opcode, payload) {
  if (opcode !== 0x1) return; // only handle text frames
  let msg;
  try {
    msg = JSON.parse(payload.toString("utf8"));
  } catch {
    return;
  }
  if (msg && msg.topic) {
    broadcast(msg.topic, msg.payload, sock); // never echo to sender
  }
}

function encode(opcode, data) {
  const len = data.length;
  let header;
  if (len < 126) {
    header = Buffer.from([0x80 | opcode, len]);
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x80 | opcode;
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x80 | opcode;
    header[1] = 127;
    header.writeUInt32BE(Math.floor(len / 2 ** 32), 2);
    header.writeUInt32BE(len >>> 0, 6);
  }
  return Buffer.concat([header, data]);
}

function encodeText(str) {
  return encode(0x1, Buffer.from(str, "utf8"));
}

// ── Keepalive: ping every 30s, drop dead sockets ──────────────────────────
setInterval(() => {
  for (const sock of clients) {
    if (!sock._alive) {
      sock.destroy();
      continue;
    }
    sock._alive = false;
    try {
      sock.write(encode(0x9, Buffer.alloc(0)));
    } catch {
      sock.destroy();
    }
  }
}, 30000);

server.on("connection", (s) => s.setTimeout(0));

server.listen(PORT, HOST, () => {
  console.log(`[realtime] broadcast hub listening on ws://${HOST}:${PORT}`);
  console.log(`[realtime] REST inject: POST http://${HOST}:${PORT}/publish {topic,payload}`);
});

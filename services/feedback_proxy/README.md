# FantasyDisk feedback relay

This is the repository-owned, dependency-free relay for FAN-1041. It keeps the
Discord webhook on the server and accepts a strict FantasyDisk protocol instead
of exposing Discord's multipart contract to the player client.

The code is ready for a single-replica deployment and is covered by local Mac
tests. It is not currently deployed. Online player feedback must remain disabled
until hosting, HTTPS/DNS, a replacement Discord webhook and durable storage are
provisioned and verified.

## Security model

- `POST /v1/session` issues a ten-minute HMAC-signed token bound to a random
  installation UUID stored under Godot `user://`.
- `POST /v1/feedback` requires that token, the installation UUID and one UUIDv4
  `Idempotency-Key`. The same key is reused for every retry.
- SQLite transactions provide single-replica rate-limit and delivery-idempotency
  state. A delivered key returns success without a second Discord post; a live
  concurrent delivery returns retryable `409`.
- Discord has no idempotency API. If its outcome is ambiguous (timeout, non-2xx,
  or a crash after dispatch), the key becomes a non-retryable tombstone and the
  client saves locally. This is an explicit at-most-once tradeoff: it prevents a
  duplicate private report but cannot guarantee delivery in the ambiguity window.
- Limits are applied per keyed IP hash and per installation hash. Raw addresses,
  player text, screenshots, tokens and webhook values are not logged.
- Only allowlisted scalar metadata and an optional bounded JPEG are accepted.
  Schema v2 forwards opted-out text-only reports as Discord JSON and image
  reports as multipart; both paths set `allowed_mentions.parse=[]`.
- The Discord upstream is restricted to an official HTTPS webhook URL from
  server environment. No client-controlled upstream URL is accepted.

Anonymous installation authorization is an abuse-control mechanism, not proof
that a request came from an official binary. Strong player identity would need
an external trust anchor such as a Steam ticket, OAuth identity or tester invite.
No reusable secret may be embedded in a desktop build.

## Required environment

```text
FEEDBACK_TOKEN_SECRET=<at least 32 random bytes>
FEEDBACK_LOG_SALT=<at least 16 independent random bytes>
FEEDBACK_DISCORD_WEBHOOK=<new server-only Discord webhook>
FEEDBACK_DATABASE_PATH=/data/feedback_proxy.sqlite3
FEEDBACK_LISTEN_HOST=0.0.0.0
FEEDBACK_LISTEN_PORT=8080
FEEDBACK_UPSTREAM_TIMEOUT=10
FEEDBACK_TRUSTED_PROXY_CIDRS=10.0.0.0/8,2001:db8:feed::/48
FEEDBACK_SESSION_GLOBAL_LIMIT=500
FEEDBACK_GLOBAL_LIMIT=120
FEEDBACK_MAX_WORKERS=24
FEEDBACK_READ_TIMEOUT=15
```

Leave `FEEDBACK_TRUSTED_PROXY_CIDRS` empty unless the service is unreachable
except through controlled reverse proxies in those exact networks. An
`X-Forwarded-For` value is accepted only from an allowlisted socket peer; all
addresses are parsed and canonicalized before keyed hashing. The proxy must
overwrite, not append to, the untrusted incoming header.

The global hourly limits are a circuit breaker in front of per-IP and
per-installation buckets. They also bound new SQLite key cardinality under
identity rotation. Choose production values from the channel's operational
capacity and keep an independent edge/WAF body/rate policy.

Running behind an HTTPS reverse proxy/WAF with request buffering, a body limit
no larger than 2 MB, connection/header/read timeouts and an independent global
rate policy is mandatory. The included internal server additionally bounds its
worker threads/backlog and socket read time; it listens on plain HTTP:

```bash
docker build -t fantasydisk-feedback-relay services/feedback_proxy
docker run --read-only --tmpfs /tmp --memory=128m --cpus=1 --pids-limit=80 \
  -v feedback-data:/data --env-file relay.env \
  -p 127.0.0.1:8080:8080 fantasydisk-feedback-relay
```

For more than one replica, replace the SQLite `Store` with shared transactional
storage before scaling. Copying local databases between replicas breaks global
rate limiting, idempotency and the at-most-once ambiguity policy.

## Verification and rollout

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_feedback_proxy
```

Before enabling `feedback/relay_session_url` in `project.godot`:

1. provision HTTPS/DNS and restrict direct origin access;
2. create a new Discord webhook only in server secret storage;
3. mount durable storage and backup/retention policy;
4. verify health, session expiry, rate limits, duplicate delivery and ambiguous
   upstream/crash fallback against staging;
5. document operator contact/data retention and ship player-facing disclosure
   for screenshot, game/OS metadata, persistent installation UUID and edge IP;
   populate all four public `feedback/privacy_*` project settings (the client
   refuses a configured relay while any disclosure value is missing);
6. run the Mac release/export secret scan and later the deferred Windows TLS test;
7. set the public endpoint to exactly `https://<host>/v1/session` and rebuild.

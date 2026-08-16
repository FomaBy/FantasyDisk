# FantasyDisk feedback relay

This is the repository-owned, dependency-free relay for FAN-1041. It keeps the
Discord webhook on the server and accepts a strict FantasyDisk protocol instead
of exposing Discord's multipart contract to the player client.

The code and provider-neutral Compose bundle are ready for a single-replica
deployment and are covered by deterministic local tests. They do not provision
or activate a service. Online player feedback must remain disabled until
hosting, HTTPS/DNS, server secrets and durable storage are separately
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

`relay.env.example` lists every accepted deployment variable with safe defaults
and blank credential placeholders. Copy it only to the ignored `relay.env` on
the target host, then inject the three blank values from that host's secret
store. Never write their values into Compose, shell history, logs or smoke
evidence.

```bash
cd services/feedback_proxy
cp relay.env.example relay.env
docker compose config
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
worker threads/backlog and socket read time; it listens on plain HTTP. Compose
publishes that origin only on host loopback, runs one read-only replica with a
bounded tmpfs, drops capabilities, limits CPU/memory/PIDs and stores SQLite on a
named durable volume:

```bash
docker compose up --build -d
docker compose ps
```

For more than one replica, replace the SQLite `Store` with shared transactional
storage before scaling. Copying local databases between replicas breaks global
rate limiting, idempotency and the at-most-once ambiguity policy.

## No-cost staging preparation

These steps validate the repository bundle without changing `project.godot`,
creating production infrastructure or sending anything to production:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest \
  tests.test_feedback_proxy tests.test_feedback_relay_smoke
python3 tools/scan_release_secrets.py \
  services/feedback_proxy tools/feedback_relay_smoke.py \
  tests/test_feedback_relay_smoke.py docs/feedback_webhook_setup.md
```

The tests start the real relay against a loopback fake Discord upstream and
cover success, duplicate/conflict, rejection and timeout behavior. Once a
separately authorized staging service exists, capture redacted machine-readable
evidence using only its public session endpoint:

```bash
python3 tools/feedback_relay_smoke.py \
  https://feedback-staging.example.org/v1/session \
  > relay-smoke-evidence.json
python3 tools/scan_release_secrets.py relay-smoke-evidence.json
```

The smoke client generates its own text-only and image test reports. It accepts
no server credential inputs and emits only check names, HTTP statuses and
redacted failure categories. Keep the resulting file out of Git unless an issue
explicitly locks an evidence path.

## Production provisioning and activation

This is a separate operational gate. Do not infer production approval from a
green local or staging smoke, and obtain owner approval before any paid hosting
or other charge. Before enabling `feedback/relay_session_url` in
`project.godot`:

1. provision HTTPS/DNS and restrict direct origin access;
2. create production-only server credentials in the production secret store;
3. mount durable storage and backup/retention policy;
4. verify health, session expiry, rate limits, duplicate delivery and ambiguous
   upstream/crash fallback against production-equivalent staging;
5. document operator contact/data retention and ship player-facing disclosure
   for screenshot, game/OS metadata, persistent installation UUID and edge IP;
   populate all four public `feedback/privacy_*` project settings (the client
   refuses a configured relay while any disclosure value is missing);
6. run the Mac release/export secret scan and later the deferred Windows TLS test;
7. approve the production change, set the public endpoint to exactly
   `https://<host>/v1/session`, rebuild and use the normal release gates.

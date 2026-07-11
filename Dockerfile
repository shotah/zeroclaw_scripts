# Optional local wrapper. Prefer the prebuilt image in docker-compose.yml:
#   ghcr.io/zeroclaw-labs/zeroclaw:latest
#
# This Dockerfile exists only if you want a named local tag. It adds no layers
# beyond the upstream distroless runtime (no Node, no custom skills bake-in).
ARG ZEROCLAW_BASE=ghcr.io/zeroclaw-labs/zeroclaw:latest
FROM ${ZEROCLAW_BASE}

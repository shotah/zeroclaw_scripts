# Thin ZeroClaw + gws: keep upstream distroless, add only the Google Workspace CLI binary.
# Upstream :latest is gcr.io/distroless/cc-debian13 (glibc). gws gnu builds need GLIBC >= 2.39,
# so the fetch stage must be Debian 13+ (trixie), not bookworm/Alpine.
#
# Build:  docker compose build
# Auth:   docs/google-workspace.md

ARG ZEROCLAW_BASE=ghcr.io/zeroclaw-labs/zeroclaw:latest
ARG GWS_VERSION=v0.22.5

# --- fetch gws (trixie/glibc 2.41 — matches distroless/cc-debian13) ------------
FROM debian:trixie-slim AS gws
ARG GWS_VERSION
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 && case "${TARGETARCH}" in \
      amd64) GWS_ARCH=x86_64-unknown-linux-gnu ;; \
      arm64) GWS_ARCH=aarch64-unknown-linux-gnu ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && curl -fsSL \
      "https://github.com/googleworkspace/cli/releases/download/${GWS_VERSION}/google-workspace-cli-${GWS_ARCH}.tar.gz" \
      -o /tmp/gws.tar.gz \
 && tar -xzf /tmp/gws.tar.gz -C /tmp \
 && install -m 0755 /tmp/gws /gws \
 && /gws --version

# --- runtime: upstream distroless + /usr/local/bin/gws ------------------------
FROM ${ZEROCLAW_BASE}
COPY --from=gws /gws /usr/local/bin/gws

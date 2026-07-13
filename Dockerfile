# Thin ZeroClaw: keep the upstream distroless image, add only the extra tool binaries.
# Upstream :latest is gcr.io/distroless/cc-debian13 (glibc). gws gnu builds need GLIBC >= 2.39,
# so the fetch stage must be Debian 13+ (trixie), not bookworm/Alpine. strava-mcp, garmin, and
# mcp-gemini-google-search are static (zero-CGO) Go binaries, so they run on distroless fine.
#
# Build:  docker compose build
# Auth:   docs/google-workspace.md (gws) · docs/strava.md · docs/garmin.md · docs/web-search.md

ARG ZEROCLAW_BASE=ghcr.io/zeroclaw-labs/zeroclaw:latest
ARG GWS_VERSION=v0.22.5
ARG STRAVA_MCP_VERSION=v1.2.0
# go-garmin has no release tarballs yet — pin a git commit (override via GARMIN_MCP_REF).
# Default: shotah/go-garmin (DI auth); upstream llehouerou is broken for new logins post-Mar 2026.
ARG GARMIN_MCP_REF=de40f7bfdc489e8b5ded3eb533586d7297513e95
# Gemini Grounding with Google Search MCP (override via GEMINI_SEARCH_MCP_REF).
ARG GEMINI_SEARCH_MCP_REF=1fe676adcdaa79ed0798fd32be0695ffee15c644

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

# --- fetch strava-mcp (static Go binary; MCP server for Strava) ---------------
FROM debian:trixie-slim AS strava
ARG STRAVA_MCP_VERSION
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 && case "${TARGETARCH}" in \
      amd64|arm64) STRAVA_ARCH="linux_${TARGETARCH}" ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && V="${STRAVA_MCP_VERSION#v}" \
 && curl -fsSL \
      "https://github.com/Stealinglight/StravaMCP/releases/download/${STRAVA_MCP_VERSION}/StravaMCP_${V}_${STRAVA_ARCH}.tar.gz" \
      -o /tmp/strava.tar.gz \
 && tar -xzf /tmp/strava.tar.gz -C /tmp \
 && install -m 0755 /tmp/strava-mcp /strava-mcp \
 && /strava-mcp --version

# --- build garmin CLI + MCP (static Go; go-garmin) ----------------------------
FROM golang:1.25-bookworm AS garmin
ARG GARMIN_MCP_REF
ARG TARGETARCH

ENV CGO_ENABLED=0
WORKDIR /src
RUN git clone https://github.com/shotah/go-garmin.git . \
 && git checkout --detach "${GARMIN_MCP_REF}" \
 && GOOS=linux GOARCH="${TARGETARCH}" go build -trimpath -ldflags="-s -w" -o /garmin ./cmd/garmin \
 && /garmin --help >/dev/null

# --- build Gemini Google Search MCP (static Go; zchee) -----------------------
FROM golang:1.26-bookworm AS gemini-search
ARG GEMINI_SEARCH_MCP_REF
ARG TARGETARCH

ENV CGO_ENABLED=0
WORKDIR /src
RUN git clone https://github.com/zchee/mcp-gemini-google-search.git . \
 && git checkout --detach "${GEMINI_SEARCH_MCP_REF}" \
 && GOOS=linux GOARCH="${TARGETARCH}" go build -trimpath -ldflags="-s -w" -o /mcp-gemini-google-search . \
 && test -x /mcp-gemini-google-search

# --- runtime: upstream distroless + tool binaries -----------------------------
FROM ${ZEROCLAW_BASE}
COPY --from=gws /gws /usr/local/bin/gws
COPY --from=strava /strava-mcp /usr/local/bin/strava-mcp
COPY --from=garmin /garmin /usr/local/bin/garmin
COPY --from=gemini-search /mcp-gemini-google-search /usr/local/bin/mcp-gemini-google-search

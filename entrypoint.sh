#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="/srv/site"
THEME_OVERLAY_DIR="/srv/overlays"
PROJECT_OVERLAY_DIR="/srv/project_overrides"
PROJECT_OBJECTS_DIR="/srv/project_objects"
OUTPUT_DIR="/srv/output"

log() { echo "[entrypoint] $*"; }

apply_overlays() {
  if [ -d "${THEME_OVERLAY_DIR}" ] && [ "$(ls -A "${THEME_OVERLAY_DIR}" 2>/dev/null || true)" ]; then
    log "Applying theme overlays"
    rsync -a --delete "${THEME_OVERLAY_DIR}/" "${SITE_DIR}/"
  fi

  if [ -d "${PROJECT_OVERLAY_DIR}" ] && [ "$(ls -A "${PROJECT_OVERLAY_DIR}" 2>/dev/null || true)" ]; then
    log "Applying project overrides"
    rsync -a --delete "${PROJECT_OVERLAY_DIR}/" "${SITE_DIR}/"
  fi
}

link_objects() {
  if [ -d "${PROJECT_OBJECTS_DIR}" ]; then
    log "Mounting project objects directory"
    rm -rf "${SITE_DIR}/objects" || true
    ln -s "${PROJECT_OBJECTS_DIR}" "${SITE_DIR}/objects"
  else
    log "No project objects directory mounted; ensuring objects directory exists"
    mkdir -p "${SITE_DIR}/objects"
  fi
}

mkdir -p "${OUTPUT_DIR}"
chmod -R a+rw "${OUTPUT_DIR}" || true

cd "${SITE_DIR}"

apply_overlays
link_objects

# Install Ruby gems
if [ -f "Gemfile" ]; then
  log "Running bundle install..."
  bundle config set --local path "${BUNDLE_PATH:-/usr/local/bundle}" || true
  bundle install --jobs=4 --retry=3
fi

# Allow custom command override
if [ $# -gt 0 ]; then
  log "Executing custom command: $*"
  exec "$@"
fi

log "Running Jekyll build..."
bundle exec jekyll build --destination "${OUTPUT_DIR}"

# Optional S3 sync
if [ -n "${S3_TARGET:-}" ]; then
  if command -v aws >/dev/null 2>&1; then
    log "Syncing output to S3: ${S3_TARGET}"
    aws s3 sync "${OUTPUT_DIR}/" "${S3_TARGET}" ${AWS_CLI_EXTRA_OPTS:-}
    log "S3 sync complete."
  else
    log "aws CLI not available; skipping S3 sync"
  fi
fi

log "Build complete."
exit 0
#!/usr/bin/env bash
set -e

log() {
  echo "[entrypoint] $1"
}

SITE_DIR="/srv/site"
THEME_OVERLAY_DIR="/srv/overlays"
PROJECT_OVERLAY_DIR="/srv/project_overrides"
PROJECT_OBJECTS_DIR="/srv/project_objects"
OUTPUT_DIR="/srv/output"

cd "${SITE_DIR}"

# Apply theme overlays (non-destructive)
if [ -d "${THEME_OVERLAY_DIR}" ] && [ "$(ls -A ${THEME_OVERLAY_DIR} 2>/dev/null)" ]; then
  log "Applying theme overlays"
  rsync -a "${THEME_OVERLAY_DIR}/" "${SITE_DIR}/"
fi

# Apply project overrides (non-destructive)
if [ -d "${PROJECT_OVERLAY_DIR}" ] && [ "$(ls -A ${PROJECT_OVERLAY_DIR} 2>/dev/null)" ]; then
  log "Applying project overrides"
  rsync -a "${PROJECT_OVERLAY_DIR}/" "${SITE_DIR}/"
fi

# Mount project objects directory if provided
if [ -d "${PROJECT_OBJECTS_DIR}" ] && [ "$(ls -A ${PROJECT_OBJECTS_DIR} 2>/dev/null)" ]; then
  log "Mounting project objects directory"
  mkdir -p "${SITE_DIR}/objects"
  rsync -a "${PROJECT_OBJECTS_DIR}/" "${SITE_DIR}/objects/"
fi

log "Running Jekyll build..."
bundle exec jekyll build --destination "${OUTPUT_DIR}"

log "Build complete."
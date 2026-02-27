#!/usr/bin/env bash
set -euo pipefail

# run-cb.sh - minimal runner with optional derivatives generation
# Usage:
#   ./run-cb.sh <project_dir> <output_dir> [--image IMAGE] [--s3 s3://bucket/path] [--derivatives]

PROJECT_DIR="${1:-}"
OUTPUT_DIR="${2:-}"
shift 2 || true

IMAGE_NAME="collectionbuilder:latest"
S3_TARGET=""
DO_DERIVATIVES=0

while (( $# )); do
  case "$1" in
    --image) IMAGE_NAME="$2"; shift 2 ;;
    --s3) S3_TARGET="$2"; shift 2 ;;
    --derivatives) DO_DERIVATIVES=1; shift 1 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [ -z "$PROJECT_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: $0 <project_dir> <output_dir> [--image IMAGE] [--s3 s3://bucket/path] [--derivatives]"
  exit 2
fi

# Resolve absolute paths
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
OUTPUT_DIR="$(mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)"
THEME_OVERLAY_DIR="$(pwd)"
PROJECT_OVERRIDE_DIR="${PROJECT_DIR}/overrides"
PROJECT_OBJECTS_DIR="${PROJECT_DIR}/objects"

mkdir -p "${PROJECT_OVERRIDE_DIR}" "${PROJECT_OBJECTS_DIR}"

echo "--------------------------------------------------"
echo "CollectionBuilder Build"
echo "Image:          ${IMAGE_NAME}"
echo "Theme overlay:  ${THEME_OVERLAY_DIR}"
echo "Project dir:    ${PROJECT_DIR}"
echo "Output dir:     ${OUTPUT_DIR}"
[ -n "${S3_TARGET}" ] && echo "S3 target:      ${S3_TARGET}"
[ "${DO_DERIVATIVES}" -eq 1 ] && echo "Derivatives:    enabled"
echo "--------------------------------------------------"

# If derivatives requested: run rake generate_derivatives (needs project_objects rw)
if [ "${DO_DERIVATIVES}" -eq 1 ]; then
  echo "Running generate_derivatives inside container..."
  docker run --rm \
    -v "${THEME_OVERLAY_DIR}:/srv/overlays:ro" \
    -v "${PROJECT_OVERRIDE_DIR}:/srv/project_overrides:ro" \
    -v "${PROJECT_OBJECTS_DIR}:/srv/project_objects:rw" \
    -v "${OUTPUT_DIR}:/srv/output:rw" \
    -w /srv/site \
    "${IMAGE_NAME}" \
    bundle exec rake generate_derivatives

  echo "Derivatives generation finished."
fi

# Run the normal build (container writes built site into OUTPUT_DIR)
echo "Running site build inside container..."
docker run --rm \
  -v "${THEME_OVERLAY_DIR}:/srv/overlays:ro" \
  -v "${PROJECT_OVERRIDE_DIR}:/srv/project_overrides:ro" \
  -v "${PROJECT_OBJECTS_DIR}:/srv/project_objects:ro" \
  -v "${OUTPUT_DIR}:/srv/output:rw" \
  "${IMAGE_NAME}"

echo "Build complete. Output written to ${OUTPUT_DIR}"

# Optional S3 sync (host-side)
if [ -n "${S3_TARGET}" ]; then
  if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: AWS CLI not found on host. Install awscli to use --s3."
    exit 3
  fi

  echo "Syncing to S3 from host..."
  aws s3 sync "${OUTPUT_DIR}/" "${S3_TARGET}"
  echo "S3 sync complete."
fi
#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./tools/upload_to_bucket.sh <bucket> <repo> <commit> <file-to-upload>
# Example:
#   ./tools/upload_to_bucket.sh my-bucket my-org/my-repo abcd123 merged.json

if [ $# -lt 4 ]; then
  echo "Usage: $0 <bucket> <repo> <commit> <file>" >&2
  exit 2
fi

BUCKET="$1"
REPO="$2"
COMMIT="$3"
FILE="$4"

PREFIX="reports/${REPO}/${COMMIT}"
if command -v gsutil >/dev/null 2>&1; then
  echo "Uploading ${FILE} to gs://${BUCKET}/${PREFIX}/"
  gsutil cp "${FILE}" "gs://${BUCKET}/${PREFIX}/"
  echo "https://storage.googleapis.com/${BUCKET}/${PREFIX}/$(basename ${FILE})"
elif command -v aws >/dev/null 2>&1; then
  # fallback to AWS S3 (requires AWS CLI + creds)
  aws s3 cp "${FILE}" "s3://${BUCKET}/${PREFIX}/"
  echo "https://${BUCKET}.s3.amazonaws.com/${PREFIX}/$(basename ${FILE})"
else
  echo "Error: neither gsutil nor aws CLI found. Install one to upload reports." >&2
  exit 3
fi

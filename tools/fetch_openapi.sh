#!/bin/bash

# Fetches the OpenAPI spec from Kavita's GitHub repository
# Usage: ./utils/fetch_openapi.sh [version]
# Example: ./utils/fetch_openapi.sh v0.8.9

set -e

VERSION="${1:-v0.9.0}"
URL="https://raw.githubusercontent.com/Kareadita/Kavita/refs/tags/${VERSION}/openapi.json"
OUTPUT="swaggers/openapi.json"

echo "Fetching OpenAPI spec for Kavita ${VERSION}..."
echo "URL: ${URL}"

curl -fSL "${URL}" -o "${OUTPUT}"

echo "Saved to ${OUTPUT}"
echo "Done! Run 'fvm dart run build_runner build --delete-conflicting-outputs' to regenerate the API client."

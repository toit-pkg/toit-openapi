#!/bin/sh
# Copyright (C) 2026 Toit contributors.
# Use of this source code is governed by an MIT-style license that can be
# found in the LICENSE file.

set -e

# Downloads the canonical OpenAPI Pet Store fixtures used by the tests.
# Pinned to specific upstream commits so test runs are reproducible.

DIR="$(cd "$(dirname "$0")" && pwd)"

# Simple v3.0 example, maintained by the OpenAPI Initiative.
STORE_URL="https://raw.githubusercontent.com/OAI/learn.openapis.org/be248e49bd/examples/v3.0/petstore.yaml"

# Fuller swagger-api Pet Store sample, pinned to v1.0.22-SNAPSHOT.
BIGGER_URL="https://raw.githubusercontent.com/swagger-api/swagger-petstore/611825423a/src/main/resources/openapi.yaml"

download() {
  url="$1"
  dest="$2"
  if [ -f "$dest" ]; then
    return 0
  fi
  echo "Downloading $(basename "$dest")..."
  curl -sSLf "$url" -o "$dest"
}

download "$STORE_URL" "$DIR/store.yaml"
download "$BIGGER_URL" "$DIR/bigger.yaml"

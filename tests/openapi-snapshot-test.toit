// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import host
import host.directory
import host.file
import host.os
import openapi-gen.openapi-gen as gen

/**
Iterates the snapshot fixtures under $SNAPSHOT-DIRS. For each subdirectory
  with a `spec.yaml`, runs the generator and byte-compares every file the
  generator emits under `<tmp>/src/` against the golden under the
  directory's golden subpath:

- `tests/snapshots/<f>/expected.toit` (api), `expected-models.toit` (models)
- `tests/e2e/<f>/api.toit` (api), `models.toit` (models)

When `OPENAPI_UPDATE_SNAPSHOTS` is set (any non-empty value), goldens are
  rewritten instead of compared. CI must never set this.

The `tests/e2e/` fixtures are also imported by `openapi-e2e-test.toit`,
  so this test guarantees those committed clients stay in sync with the
  generator.
*/

SPEC-NAME ::= "spec.yaml"
UPDATE-ENV ::= "OPENAPI_UPDATE_SNAPSHOTS"

// Each entry is a fixture-directory layout: [dir, api-golden, models-golden].
SNAPSHOT-DIRS ::= [
  ["tests/snapshots", "expected.toit", "expected-models.toit"],
  ["tests/e2e", "api.toit", "models.toit"],
]

main:
  update-mode := (os.env.get UPDATE-ENV) != null
  failures := []
  total := 0
  SNAPSHOT-DIRS.do: | entry/List |
    dir/string := entry[0]
    api-golden/string := entry[1]
    models-golden/string := entry[2]
    fixtures := list-fixtures_ dir
    fixtures.do: | name/string |
      spec-path := "$dir/$name/$SPEC-NAME"
      if not (file.is-file spec-path): continue.do  // Not a fixture dir.
      total++

      generated := generate_ spec-path
      api/string := generated["api.toit"]
      models/string? := generated.get "models.toit"

      check-golden_ "$dir/$name/$api-golden" api
          --update-mode=update-mode
          --failures=failures
          --label="$dir/$name"
      models-path := "$dir/$name/$models-golden"
      if models:
        check-golden_ models-path models
            --update-mode=update-mode
            --failures=failures
            --label="$dir/$name (models)"
      else if file.is-file models-path:
        if update-mode:
          file.delete models-path
          print "removed stale $models-path"
        else:
          failures.add "$dir/$name: $models-path exists but generator emitted no models. Run with $UPDATE-ENV=1 to remove."

  expect (total > 0) --message="no snapshot fixtures found"
  if not failures.is-empty:
    failures.do: print it
    throw "snapshot mismatch"

check-golden_ path/string actual/string
    --update-mode/bool
    --failures/List
    --label/string -> none:
  if update-mode:
    file.write-contents --path=path actual
    print "updated $path"
    return
  if not (file.is-file path):
    failures.add "$label: missing $path. Run with $UPDATE-ENV=1 to create it."
    return
  expected := (file.read-contents path).to-string
  if expected != actual:
    failures.add "$label: generated output does not match $path. Run with $UPDATE-ENV=1 to bless."

list-fixtures_ root/string -> List:
  if not (file.is-directory root): return []
  result := []
  stream := directory.DirectoryStream root
  try:
    while name := stream.next:
      if file.is-directory "$root/$name": result.add name
  finally:
    stream.close
  result.sort --in-place
  return result

/// Returns a map from generated filename ("api.toit", "models.toit", ...) to
/// its source string.
generate_ spec-path/string -> Map:
  files := {:}
  host.with-tmp-directory "/tmp/openapi-snapshot-": | tmp-dir |
    gen.main [spec-path, tmp-dir]
    src-dir := "$tmp-dir/src"
    expect (file.is-directory src-dir) --message="generator did not write $src-dir"
    stream := directory.DirectoryStream src-dir
    try:
      while name := stream.next:
        path := "$src-dir/$name"
        if file.is-file path:
          files[name] = (file.read-contents path).to-string
    finally:
      stream.close
  return files

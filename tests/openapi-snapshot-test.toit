// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import host.directory
import host.file
import host.os
import openapi-gen.openapi-gen as gen

/**
Iterates the snapshot fixtures under $SNAPSHOT-DIRS. For each subdirectory
  with a `spec.yaml`, it runs the generator and byte-compares the resulting
  `src/api.toit` against the golden file (whose name is configured per
  directory, see $SNAPSHOT-DIRS).

When the env var `OPENAPI_UPDATE_SNAPSHOTS` is set (any non-empty value), the
  test rewrites the golden from the generator output instead of failing.
  CI must never set this.

Both `tests/snapshots/` and the e2e fixtures under `tests/e2e/` are checked,
  so a drift between the committed `api.toit` used by the e2e test and what
  the current generator produces will fail this test.
*/

SPEC-NAME ::= "spec.yaml"
UPDATE-ENV ::= "OPENAPI_UPDATE_SNAPSHOTS"

// Each entry is [directory, golden-file-name].
SNAPSHOT-DIRS ::= [
  ["tests/snapshots", "expected.toit"],
  ["tests/e2e", "api.toit"],
]

main:
  update-mode := (os.env.get UPDATE-ENV) != null
  failures := []
  total := 0
  SNAPSHOT-DIRS.do: | entry/List |
    dir/string := entry[0]
    golden/string := entry[1]
    fixtures := list-fixtures_ dir
    fixtures.do: | name/string |
      total++
      spec-path := "$dir/$name/$SPEC-NAME"
      golden-path := "$dir/$name/$golden"
      if not (file.is-file spec-path): continue.do  // Not a fixture dir.

      actual := generate_ spec-path

      if update-mode:
        file.write-contents --path=golden-path actual
        print "updated $golden-path"
        continue.do

      if not (file.is-file golden-path):
        failures.add "$dir/$name: missing $golden-path. Run with $UPDATE-ENV=1 to create it."
        continue.do

      expected := (file.read-contents golden-path).to-string
      if expected != actual:
        failures.add "$dir/$name: generated output does not match $golden-path. Run with $UPDATE-ENV=1 to bless."

  expect (total > 0) --message="no snapshot fixtures found"
  if not failures.is-empty:
    failures.do: print it
    throw "snapshot mismatch"

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

generate_ spec-path/string -> string:
  tmp-dir := directory.mkdtemp "/tmp/openapi-snapshot-"
  try:
    gen.main [spec-path, tmp-dir]
    api-path := "$tmp-dir/src/api.toit"
    expect (file.is-file api-path) --message="generator did not write $api-path"
    return (file.read-contents api-path).to-string
  finally:
    directory.rmdir --recursive tmp-dir

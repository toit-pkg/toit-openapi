// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import host.directory
import host.file
import host.os
import openapi-gen.openapi-gen as gen

/**
Iterates the snapshot fixtures under $SNAPSHOTS-DIR. For each subdirectory
  with a `spec.yaml`, it runs the generator and byte-compares the resulting
  `src/api.toit` against `expected.toit`.

When the env var `OPENAPI_UPDATE_SNAPSHOTS` is set (any non-empty value), the
  test rewrites `expected.toit` from the generator output instead of failing.
  CI must never set this.
*/

SNAPSHOTS-DIR ::= "tests/snapshots"
SPEC-NAME ::= "spec.yaml"
EXPECTED-NAME ::= "expected.toit"
UPDATE-ENV ::= "OPENAPI_UPDATE_SNAPSHOTS"

main:
  update-mode := (os.env.get UPDATE-ENV) != null
  fixtures := list-fixtures_
  expect (not fixtures.is-empty) --message="no snapshot fixtures found in $SNAPSHOTS-DIR"
  failures := []
  fixtures.do: | name/string |
    spec-path := "$SNAPSHOTS-DIR/$name/$SPEC-NAME"
    expected-path := "$SNAPSHOTS-DIR/$name/$EXPECTED-NAME"
    expect (file.is-file spec-path) --message="missing $spec-path"

    actual := generate_ spec-path

    if update-mode:
      file.write-contents --path=expected-path actual
      print "updated $expected-path"
      continue.do

    if not (file.is-file expected-path):
      failures.add "$name: missing $expected-path. Run with $UPDATE-ENV=1 to create it."
      continue.do

    expected := (file.read-contents expected-path).to-string
    if expected != actual:
      failures.add "$name: generated output does not match $expected-path. Run with $UPDATE-ENV=1 to bless."

  if not failures.is-empty:
    failures.do: print it
    throw "snapshot mismatch"

list-fixtures_ -> List:
  if not (file.is-directory SNAPSHOTS-DIR): return []
  result := []
  stream := directory.DirectoryStream SNAPSHOTS-DIR
  try:
    while name := stream.next:
      if file.is-directory "$SNAPSHOTS-DIR/$name": result.add name
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

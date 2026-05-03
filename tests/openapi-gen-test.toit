// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import host.directory
import host.file
import openapi-gen.openapi-gen as gen

TEMPLATE-PATH ::= "openapi-template/api.toit"

main:
  test-generates "tests/pet-store/store.yaml" --expected-classes=["Api", "PetsApi"]
  test-generates "tests/pet-store/bigger.yaml"
      --expected-classes=["Api", "PetApi", "StoreApi", "UserApi"]

test-generates spec-path/string --expected-classes/List:
  tmp-dir := directory.mkdtemp "/tmp/openapi-gen-test-"
  try:
    gen.main ["--template", TEMPLATE-PATH, spec-path, tmp-dir]
    api-path := "$tmp-dir/src/api.toit"
    expect (file.is-file api-path) --message="generator did not write $api-path"
    contents := (file.read-contents api-path).to-string
    expect (contents.contains "import openapi-runtime")
        --message="generated api.toit does not import openapi-runtime"
    expected-classes.do: | cls/string |
      expect (contents.contains "class $cls")
          --message="generated api.toit is missing class $cls"
  finally:
    directory.rmdir --recursive tmp-dir

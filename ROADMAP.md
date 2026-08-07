# OpenAPI for Toit roadmap

This document tracks the work required before the OpenAPI client generator is
ready to publish. It covers these repositories as one system:

- `toit-gen`
- `toit-json-schema`
- `toit-openapi-runtime`
- `toit-openapi`

The repositories intentionally use local path dependencies during development.
Published, versioned dependencies are a release-readiness task, not a
prerequisite for normal cross-repository work.

## Working method

Work is organized in dependency waves. Within each repository, related changes
are submitted as a stack of small pull requests; each PR targets the branch
immediately below it. Cross-repository changes cannot be one GitHub PR stack,
so dependencies between repository-local stacks are recorded explicitly here.

Status markers:

- [ ] queued
- [~] in progress
- [x] complete
- [!] blocked, with the blocker stated on the item

The generator follows a correctness contract: accepting a construct means the
generated client represents it faithfully. Constructs that cannot yet be
represented must produce a structured generation diagnostic. Silently falling
back to `any`, `ByteArray`, `null`, or a runtime `UNIMPLEMENTED` is not an
acceptable final behavior when it changes wire semantics.

## Wave 0: code-generation foundation (`toit-gen`)

- [x] **GEN-001 — Escape generated source text.** Correctly render string
  literals, interpolation text, and Toitdoc content containing quotes,
  backslashes, dollar signs, control characters, newlines, or comment
  terminators. Includes adversarial render-and-analyze tests. Implemented on
  `toit-gen:floitsch/000-escape-generated-text` at `a02f7c0`.
- [x] **GEN-002 — Represent field-initializing constructor parameters.** Add
  `.field` and `--.field=default` parameters to the AST and renderer so
  immutable generated classes can expose ordinary constructors. Implemented
  on `toit-gen:floitsch/001-field-initializing-parameters` at `1385a69`.
- [ ] **GEN-003 — Complete qualified core/import rendering.** Make imported
  references work consistently in every expression and type position, and
  support an always-prefixed `core` import so generated schema names cannot
  shadow `Map`, `List`, or other core types.
- [ ] **GEN-004 — Validate ASTs before rendering.** Report structured errors
  for unsupported or internally inconsistent AST shapes instead of failing
  partway through output with generic exceptions.
- [ ] **GEN-005 — Make filesystem generation atomic.** Render completely before
  replacing output files and close streams reliably on failures.

## Wave 1: schema-model foundation (`toit-json-schema`)

Depends on the relevant Wave 0 layers.

- [x] **SCHEMA-001 — Separate presence from nullability.** Compute `required`
  and `allows-null` independently; preserve absent versus explicit-null values
  through `from-json` and `to-json`. Implemented on
  `toit-json-schema:floitsch/001-property-presence` at `fa787ad` for the
  currently supported object schemas; broader composition forms remain under
  SCHEMA-004.
- [x] **SCHEMA-002 — Generate immutable models.** The former mixin-based
  inheritance design no longer requires mutable public fields. Generate final
  readable fields, ordinary constructors, and an explicit way to
  set or clear optional nullable properties while preserving presence. Final
  fields and ordinary named constructors are implemented on
  `toit-json-schema:floitsch/000-final-model-fields` at `fd65a9d`; explicit
  presence semantics are completed by SCHEMA-001 at `fa787ad`.
- [ ] **SCHEMA-003 — Expose wire conversion through `Models`.** Move recursive
  JSON encode/decode knowledge out of OpenAPI's private `WireShape_` duplicate
  and expose it through the public schema-model generation result.
- [ ] **SCHEMA-004 — Make composition semantically sound.** Distinguish
  `oneOf` from `anyOf`, support or diagnose inline variants, validate
  discriminator mappings, and reject incompatible `allOf` property collisions.
- [ ] **SCHEMA-005 — Broaden generated type support.** Cover enums, defaults,
  formats, tuples/prefix items, nullable root objects, constraints useful to
  constructors, and recursive/multi-type schemas without unsafe degradation.
- [ ] **SCHEMA-006 — Add structured code-generation diagnostics.** Schema forms
  that cannot be represented faithfully must report schema locations and
  reasons to callers.
- [ ] **SCHEMA-007 — Harden conformance testing.** Treat validation exceptions
  as failures, pin the upstream JSON Schema test-suite revision, test generated
  models by executing round trips, and update stale documented counts.
- [ ] **SCHEMA-008 — Make remote resource loading explicit and bounded.** Offer
  offline-by-default or allowlisted loading for untrusted schemas, with limits
  and clear diagnostics.

## Wave 2: HTTP runtime (`toit-openapi-runtime`)

Can proceed in parallel with most of Wave 1.

- [ ] **RUNTIME-001 — Add CI.** Run the runtime suite on the supported SDK and
  operating-system matrix before publishing.
- [ ] **RUNTIME-002 — Complete parameter serialization.** Implement OpenAPI
  defaults and supported style/explode combinations consistently for path,
  query, header, and cookie parameters, including `allowReserved` and nested
  values where specified.
- [ ] **RUNTIME-003 — Add structured response and error handling.** Represent
  non-success responses, status/content-type mismatches, empty bodies, response
  headers, and decoding failures without losing the raw response.
- [ ] **RUNTIME-004 — Add request media encoders.** Implement multipart bodies
  and correct nested form encoding; retain binary and streaming request paths.
- [ ] **RUNTIME-005 — Complete authentication.** Do not cache callback bearer
  tokens forever; add OAuth2/OpenID Connect flows and scopes, mutual TLS hooks,
  and precise errors for unsatisfied requirements.
- [ ] **RUNTIME-006 — Harden transport behavior.** Define URI joining, closing
  behavior, timeouts/cancellation, default headers, and safe handling of empty
  request bodies.

## Wave 3: OpenAPI parser and client generator (`toit-openapi`)

- [ ] **OPENAPI-001 — Finish Path Item parsing.** Remove the leftover valid-input
  failure, parse Path Item servers, and correctly resolve Path Item references.
- [ ] **OPENAPI-002 — Add a capability/diagnostic pass.** Traverse the parsed
  document before AST generation and collect structured errors and warnings
  with paths, methods, and source locations. Diagnostics are permanent;
  individual unsupported-feature errors disappear as support lands.
- [ ] **OPENAPI-003 — Resolve and merge effective parameters.** Combine path and
  operation parameters by `(name, in)`, resolve component references, enforce
  required path parameters, and pass effective serialization defaults.
- [ ] **OPENAPI-004 — Complete request-body generation.** Respect optional
  request bodies, select or expose multiple media types, integrate schema wire
  conversion, and route JSON, form, multipart, text, binary, and streaming data
  correctly.
- [ ] **OPENAPI-005 — Generate response dispatch.** Select schemas by actual
  status and content type; return primitives and ordinary collections; handle
  empty, binary, text, and error responses; expose response headers.
- [ ] **OPENAPI-006 — Complete server handling.** Implement root/path/operation
  precedence, variables, multiple servers, relative URI resolution, and robust
  joining.
- [ ] **OPENAPI-007 — Support external OpenAPI references.** Resolve documents
  relative to their source URI using controlled resource loading, with cycle
  handling and useful diagnostics.
- [ ] **OPENAPI-008 — Complete client-facing security generation.** Resolve
  referenced schemes and connect runtime OAuth2, OpenID Connect, mutual TLS,
  and scopes.
- [ ] **OPENAPI-009 — Cover advanced OpenAPI operations.** Implement or
  explicitly scope webhooks, callbacks, links, and real Runtime Expression
  parsing.
- [ ] **OPENAPI-010 — Generate a consumable package.** Emit `package.yaml`, a
  README, and an example; use the correct `toit-pkg` repository identifiers
  when publication begins.
- [ ] **OPENAPI-011 — Harden the CLI and regeneration.** Add structured command
  options and nonzero failures, atomically replace generated output, and remove
  stale generated files through a manifest.
- [ ] **OPENAPI-012 — Exercise the current generator end to end.** Generate,
  analyze, compile, and execute clients during the same test run rather than
  relying on checked-in E2E clients. Add regression fixtures for every
  capability and diagnostic above.

## Wave 4: publication readiness

- [ ] Replace development path dependencies with published URL/version
  dependencies and establish compatible release ordering.
- [ ] Reconcile SDK constraints and lock files across packages and tests.
- [ ] Complete user documentation, supported-feature tables, migration notes,
  and examples.
- [ ] Run compatibility tests against a representative corpus of real OpenAPI
  specifications, not only Petstore-style fixtures.
- [ ] Publish prereleases of all four packages and validate clean installation
  outside the sibling-repository workspace.

## Repository-local stack order

The initial intended order is:

1. `toit-gen`: GEN-001 → GEN-002 → GEN-003 → GEN-004 → GEN-005.
2. `toit-json-schema`: SCHEMA-001 → SCHEMA-002 → SCHEMA-003, with composition,
   diagnostics, and coverage layered above them.
3. `toit-openapi-runtime`: CI first, then parameter serialization, response
   handling, media encoders, authentication, and transport hardening.
4. `toit-openapi`: parser cleanup and diagnostics first, then parameters,
   bodies, responses, servers/references/security, packaging, and full E2E.

Items may move between adjacent PRs when a testable change cannot be separated,
but each layer should remain independently reviewable and green.

## Active stack coordinates

- `toit-gen`: `floitsch/000-escape-generated-text` (`a02f7c0`) →
  `floitsch/001-field-initializing-parameters` (`1385a69`).
- `toit-json-schema`: `floitsch/000-final-model-fields` (`fd65a9d`) →
  `floitsch/001-property-presence` (`fa787ad`), depending on the two `toit-gen`
  layers above.
- `toit-openapi`: `floitsch/000-project-tracker` (`e4acf84`) →
  `floitsch/001-final-model-snapshots` (`481a0f5`). The second layer depends on
  the first schema and both generator layers above. The next layer is
  `floitsch/002-property-presence-snapshots` (`033fca4`), depending on the
  second schema layer.

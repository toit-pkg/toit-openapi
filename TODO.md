# Plan

## Status

Phases 1–4 done.
- `tests/snapshots/` pins generator output, byte-for-byte, and is re-blessed
  with `OPENAPI_UPDATE_SNAPSHOTS=1`.
- `tests/e2e/` runs the generated clients against an in-process `TestServer`
  (replaces the role Prism would have played).
- `tests/prism/` is gone.
- `components.schemas.*` round-trips through real `models.toit` classes.

The next phase tackles the gaps that prevent `tests/pet-store/bigger.yaml`
  from compiling, plus the missing `servers` plumbing.

## Phase 5 — make `bigger.yaml` work

`bigger.yaml` is the canonical "real spec" smoke test. Today its generated
`api.toit` fails `toit analyze` and any operation whose body or response
is a collection silently returns `null`. Two related sub-phases.

### 5a — `servers` / base path

Trivial. Today `openapi-gen.toit:298` hardcodes `--base-path=""` in the
`Api network/net.Client` convenience constructor.

- Read `openapi.servers[0].url` (default `""` when absent or empty).
- Plumb it through as the `--base-path` literal.
- Defer multi-server fan-out and `{variable}` substitution — neither
  blocks `bigger.yaml`.
- Snapshot fixture `17-server-base-path/`.

### 5b — inline collection bodies & responses

Today `simple-type-of_` short-circuits any `type: array` / `type: object`
schema to a core type, so:
- inline `type: array` request bodies pass a raw `List` to `invoke-api`,
  which fails the `Data` type check;
- inline `type: array` and `type: object additionalProperties: …` responses
  are skipped by `response-model_`, so the regular variant returns `null`
  when the caller wants a list/map.

Fix: keep the formal Toit type loose (`List`, `Map` — Toit has no generics
so we don't try to spell the element type) but generate encode/decode code
that walks the schema shape.

Sketch:
- New `WireShape_` (private, in `openapi-gen.toit`) classifies a schema as
  one of:
  - `passthrough` — primitive, `ByteArray`, untyped `Map`/`List`,
  - `model { class }` — needs `Class.from-json` / `expr.to-json`,
  - `list  { element/WireShape_ }` — recurse,
  - `typed-map { element/WireShape_ }` — recurse, key always `string`.
- `TypeResolver` exposes `shape-of schema -> WireShape_` alongside `resolve`.
- Body emission: build the encode expression by recursing on the shape;
  emit only the `.map: …` / `.to-json` chain that the shape actually needs
  (primitive bodies stay pass-through). Replaces today's
  `is-model-class_ ? json.encode body.to-json : body` toggle.
- Response decoding mirrors the same recursion to build a typed value
  from `(json.decode response.body.read-all)`.
- Regular-variant return type: `List` for array-of-anything, `Map` for
  typed-map-of-anything, model class otherwise.

#### Snapshot fixtures

- `17-server-base-path/` — Phase 5a.
- `18-array-body-of-model/` — POST with `type: array, items: $ref: Pet`.
- `19-array-response-of-model/` — GET returning `type: array, items: $ref: Pet`.
- `20-map-response-additional-props/` — GET returning
  `type: object, additionalProperties: $ref: Pet` and a primitive variant.

#### E2E coverage

One new fixture under `tests/e2e/` round-trips a `List<Pet>`: POST a list
body, server echoes, assert request body decodes back to the original
list, assert response is a `List` of `Pet` instances.

#### Acceptance gate

`bigger.yaml` analyzes cleanly. Add a one-line analyze step to
`openapi-gen-test.toit` so regressions can't sneak back in.

## Upstream TODOs in repos we own

These are blockers we hit while exercising real specs but that don't
belong in this repo. Track them where the fix lives.

### `toit-json-schema`

- `from-json` / `to-json` for nullable `$ref` and `type: array` fields don't
  null-guard. `Pet.from-json` calls `Category.from-json data["category"]`
  even when the key is missing/null; `Pet.to-json` calls `category.to-json`
  on null. Both crash on real responses where optional `$ref` fields are
  omitted. Fix by null-checking before recursing (and skipping null entries
  on serialize).
- Generated `models.toit` carries an unused `import core`. Drop it.
- (Refactor, not blocker.) Phase 5b open-codes the `convert-from-json` /
  `convert-to-json` recursion that already exists on `SchemaType` inside
  `gen.toit`. Once Phase 5b is green, lift those onto `Models` as a public
  API and call into them from openapi-gen — current duplication is a small
  amount of code that we'll regret if (when) we need `oneOf` / `allOf`.

### `toit-gen`

No changes anticipated for Phase 5. Add items here if 5b's wire-shape
recursion exposes a missing AST construct.

## Out of scope, in rough priority order

1. Security / `securitySchemes` wiring (Phase 6 candidate). Skeleton exists
   on tag classes but `authentication` is never threaded into `invoke-api`.
   Start with `apiKey` (header/query/cookie) and `http: bearer`; defer
   `oauth2` until needed (use `toit-auth` when we do).
2. Other request-body media types (Phase 7 candidate): `multipart/form-data`
   and `application/x-www-form-urlencoded`. Runtime already accepts
   `--form-params`; the generator just needs to route to it.
3. Generated `package.yaml` / `README` / example `main` (Phase 8 candidate).
4. `oneOf` / `allOf` / `anyOf` / `discriminator` model generation (depends
   on `toit-json-schema` support).
5. Multiple response media types and response headers.
6. `webhooks` / `callbacks` / `links`.
7. Parser TODOs (`src/openapi.toit:154`, `:955`, `:1885`): empty security
   requirement `{}`, real `RuntimeExpression` parsing.

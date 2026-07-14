# Plan

## Status

Phases 1–5 done.

- `tests/snapshots/` pins generator output, byte-for-byte, and is
  re-blessed with `OPENAPI_UPDATE_SNAPSHOTS=1`.
- `tests/e2e/` runs generated clients against an in-process `TestServer`,
  including a `List<Pet>` round-trip that exercises the new shape-driven
  encode/decode path.
- `tests/prism/` is gone.
- `components.schemas.*` round-trips through real `models.toit` classes.
- `servers[0].url` is baked into the convenience constructor's `--base-path`.
- Inline `type: array` / `type: object additionalProperties` bodies and
  responses go through a recursive `WireShape_` that emits the right
  per-element `to-json` / `Class.from-json` walk.
- `openapi-gen-test.toit` runs `toit analyze` on the generated client
  for both `store.yaml` and `bigger.yaml`; regressions that break
  compilation now fail the suite.

## Upstream TODOs in repos we own

These are blockers we hit while exercising real specs but the fix lives
elsewhere. Track them here so they don't get forgotten.

### `toit-json-schema`

- **`import core` in generated `models.toit` is half-finished, not
  unused.** It is intentional groundwork so generated code can reference
  core types as `core.Map` when a schema-derived class would shadow them.
  The prefixed-rendering half was never implemented (refs still render
  bare, and `toit-gen`'s `Import.is-core` hook is defined but unwired).
  Don't drop the import — finish it: render refs through the core import
  with the `core.` prefix (always-prefix is the simple shadow-proof
  option; collision-only prefixing needs name-collision detection in
  toit-gen's render pass).
- **(refactor)** Phase 5b open-coded a smaller version of the
  `convert-from-json` / `convert-to-json` recursion that already lives on
  `SchemaType` inside `gen.toit` (private). Now that we have a concrete
  consumer, lift those onto the public `Models` surface and rewrite
  `WireShape_` to delegate. Pays off the moment we need to support
  `oneOf` / `allOf` / `anyOf` / `discriminator`, which the current
  open-coded version doesn't model.

### `toit-gen`

- **formatter can't handle a `.map: | … |` block inside a parenthesized
  argument.** `json.encode (body.map: | it | it.to-json)` comes out with
  the closing `)` on a wrongly-indented line and the parser rejects it.
  Phase 5b works around it by hoisting any `.map` walk into a local
  before passing to `json.encode`. The hoist is gated on
  `WireShape_.produces-block`. When the formatter learns to wrap the
  block at the right indent, drop the `produces-block` branch in
  `openapi-gen.toit`.

## Out of scope, in rough priority order

1. Security / `securitySchemes` wiring (next). Skeleton exists on tag
   classes but `authentication` is never threaded into `invoke-api`.
   Start with `apiKey` (header/query/cookie) and `http: bearer`; defer
   `oauth2` until needed (use `toit-auth` when we do).
2. Other request-body media types: `multipart/form-data` and
   `application/x-www-form-urlencoded`. Runtime already accepts
   `--form-params`; the generator just needs to route to it.
3. Generated `package.yaml` / `README` / example `main`.
4. `oneOf` / `allOf` / `anyOf` / `discriminator` model generation
   (depends on the toit-json-schema refactor above).
5. Multiple response media types and response headers.
6. `webhooks` / `callbacks` / `links`.
7. Multi-server fan-out and `{variable}` substitution in `servers[]`.
8. Parser TODOs (`src/openapi.toit:154`, `:955`, `:1885`): empty
   security requirement `{}`, real `RuntimeExpression` parsing.

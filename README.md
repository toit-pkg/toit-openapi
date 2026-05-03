# openapi-gen

OpenAPI 3.1 spec parser and Toit client-code generator.

This package contains:

- `src/openapi.toit` — an in-memory model and parser for OpenAPI 3.1 documents,
  built on top of `json-schema` and `json-pointer`.
- `src/openapi-gen.toit` — a CLI that consumes an OpenAPI document and emits a
  Toit client library by rendering `openapi-template/api.toit` with mustache.
- The generated client uses the
  [openapi-runtime](https://github.com/toitware/toit-openapi-runtime) package
  for its HTTP/auth runtime.

## Usage

Generate a client for an OpenAPI spec:

```sh
toit run src/openapi-gen.toit -- path/to/openapi.yaml path/to/output-dir
```

The generated `output-dir/src/api.toit` imports `openapi-runtime` and `http`,
so the consuming project needs both as dependencies.

## Testing

Tests live under `tests/`. To set up dependencies and run them:

```sh
make test
```

Some tests use Pet Store fixtures from upstream. They are downloaded on demand
by `tests/pet-store/download.sh` (also wired into `make download-fixtures`).

## License

MIT — see [LICENSE](LICENSE).

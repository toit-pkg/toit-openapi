// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import encoding.json
import http
import openapi-runtime

import .e2e.server show TestServer
import .e2e.get-with-query.api as get-with-query
import .e2e.path-param.api as path-param
import .e2e.header-param.api as header-param
import .e2e.cookie-param.api as cookie-param
import .e2e.post-binary-body.api as post-binary-body
import .e2e.multi-tag.api as multi-tag
import .e2e.components-schema.api as components-schema
import .e2e.components-schema.models as components-schema-models
import .e2e.array-round-trip.api as array-round-trip
import .e2e.array-round-trip.models as array-round-trip-models

main:
  test-get-with-query
  test-path-param
  test-header-param
  test-cookie-param
  test-post-binary-body
  test-multi-tag-and-close
  test-components-schema-round-trip
  test-array-round-trip

/**
Builds an `ApiClient` pointed at $server's loopback address.
*/
make-client_ server/TestServer -> openapi-runtime.ApiClient:
  return openapi-runtime.ApiClient server.network --base-path=server.base-path

with-server [block] -> none:
  server := TestServer
  server.start
  try:
    block.call server
  finally:
    server.close

test-get-with-query:
  with-server: | server/TestServer |
    api := get-with-query.Api --api-client=(make-client_ server)

    // Required-only call.
    response := api.items-api.search --raw --q="frog"
    expect-equals 200 response.status-code
    request := server.recorded[0]
    expect-equals "GET" request.method
    expect-equals "/search" request.resource
    expect-equals "frog" (request.query.get "q")
    expect-null (request.query.get "limit")

    // Required + optional.
    server.recorded.clear
    api.items-api.search --raw --q="frog" --limit=5
    request = server.only-request
    expect-equals "frog" (request.query.get "q")
    expect-equals "5" (request.query.get "limit")

    // No response model in this spec, so the regular variant still
    //   returns null (cf. test-components-schema-round-trip for the
    //   case where it returns a deserialized model).
    server.recorded.clear
    result := api.items-api.search --q="frog"
    expect-null result
    expect-equals 1 server.recorded.size

test-path-param:
  with-server: | server/TestServer |
    api := path-param.Api --api-client=(make-client_ server)
    api.items-api.get-item --raw --item-id="42"
    request := server.only-request
    expect-equals "GET" request.method
    expect-equals "/items/42" request.resource

test-header-param:
  with-server: | server/TestServer |
    api := header-param.Api --api-client=(make-client_ server)
    api.items-api.ping --raw --x-trace-id="abc-123"
    request := server.only-request
    expect-equals "abc-123" (request.headers.single "X-Trace-Id")

test-cookie-param:
  with-server: | server/TestServer |
    api := cookie-param.Api --api-client=(make-client_ server)
    api.items-api.ping --raw --session="sess-1" --csrf="tok-9"
    request := server.only-request
    cookie := request.headers.single "Cookie"
    expect-equals "session=sess-1; csrf=tok-9" cookie

test-post-binary-body:
  with-server: | server/TestServer |
    api := post-binary-body.Api --api-client=(make-client_ server)
    body := #[0x42, 0x65, 0x65, 0x66]
    api.items-api.upload --raw body
    request := server.only-request
    expect-equals "POST" request.method
    expect-equals "/upload" request.resource
    expect-equals body request.body

test-multi-tag-and-close:
  with-server: | server/TestServer |
    api := multi-tag.Api --api-client=(make-client_ server)
    api.pets-api.list-pets --raw
    api.users-api.list-users --raw
    expect-equals 2 server.recorded.size
    expect-equals "/pets" server.recorded[0].resource
    expect-equals "/users" server.recorded[1].resource
    api.close

test-components-schema-round-trip:
  with-server: | server/TestServer |
    server.on "POST" "/pets": | response |
      response.status = 201
      response.body = """{"id": 7, "name": "echoed"}""".to-byte-array
      response.headers["Content-Type"] = "application/json"

    api := components-schema.Api --api-client=(make-client_ server)
    sent := components-schema-models.Pet.from-json {"id": 1, "name": "frog"}

    // Regular variant returns a Pet, having JSON-encoded the request body
    //   and deserialized the response.
    received := api.pets-api.create-pet sent
    expect-equals 7 received.id
    expect-equals "echoed" received.name

    request := server.only-request
    expect-equals "POST" request.method
    expect-equals "/pets" request.resource
    decoded := json.decode request.body
    expect-equals 1 decoded["id"]
    expect-equals "frog" decoded["name"]

test-array-round-trip:
  with-server: | server/TestServer |
    server.on "POST" "/pets/batch": | response |
      response.status = 200
      response.body = """[{"id": 7, "name": "echoed-frog"}, {"id": 8, "name": "echoed-toad"}]""".to-byte-array
      response.headers["Content-Type"] = "application/json"

    api := array-round-trip.Api --api-client=(make-client_ server)
    sent := [
      array-round-trip-models.Pet.from-json {"id": 1, "name": "frog"},
      array-round-trip-models.Pet.from-json {"id": 2, "name": "toad"},
    ]

    // Regular variant: each Pet in the request body got serialized via
    //   to-json, the wire payload is a JSON array, and the response is
    //   decoded back into a List of Pet instances.
    received/List := api.pets-api.create-pets sent
    expect-equals 2 received.size
    expect-equals 7 received[0].id
    expect-equals "echoed-frog" received[0].name
    expect-equals 8 received[1].id
    expect-equals "echoed-toad" received[1].name

    request := server.only-request
    expect-equals "POST" request.method
    expect-equals "/pets/batch" request.resource
    decoded/List := json.decode request.body
    expect-equals 2 decoded.size
    expect-equals 1 decoded[0]["id"]
    expect-equals "frog" decoded[0]["name"]
    expect-equals 2 decoded[1]["id"]
    expect-equals "toad" decoded[1]["name"]

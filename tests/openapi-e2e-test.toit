// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import http
import openapi-runtime

import .e2e.server show TestServer
import .e2e.get-with-query.api as get-with-query
import .e2e.path-param.api as path-param
import .e2e.header-param.api as header-param
import .e2e.cookie-param.api as cookie-param
import .e2e.post-binary-body.api as post-binary-body
import .e2e.multi-tag.api as multi-tag

main:
  test-get-with-query
  test-path-param
  test-header-param
  test-cookie-param
  test-post-binary-body
  test-multi-tag-and-close

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

    // The regular variant (Phase 4 will change this) returns null.
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

// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import http
import io
import monitor
import net

/**
A captured HTTP request as the test server saw it.
*/
class RecordedRequest:
  method/string
  /**
  The full request path, e.g. "/items/42?limit=5".
  */
  path/string
  /**
  The path with the query string stripped, e.g. "/items/42".
  */
  resource/string
  /**
  Query parameters, parsed from the path. Each value is either a string
    (single occurrence) or a list of strings (repeated key).
  */
  query/Map
  headers/http.Headers
  body/ByteArray

  constructor --.method --.path --.resource --.query --.headers --.body:

/**
A canned response to a recorded request.

Defaults to status 200 with no body. Use $body / $headers / $status to
  customize.
*/
class CannedResponse:
  status/int := 200
  body/ByteArray := #[]
  /**
  Extra response headers to set on the writer before writing the body.
  */
  headers/Map := {:}

/**
A small test HTTP server used to drive the generated OpenAPI clients.

Records every incoming request and replies with a canned response keyed by
  `(method, resource)`. If no canned response is configured, returns 200
  with an empty body.
*/
class TestServer:
  network/net.Client? := null
  socket_ := null
  server_/http.Server? := null
  task_ := null
  port_/int := 0

  recorded/List := []
  // (method, resource) -> CannedResponse
  responses_/Map := {:}

  /**
  Starts the server on a free port and returns once it is ready to accept
    connections. The port is available as $port.
  */
  start -> none:
    network = net.open
    socket_ = network.tcp-listen 0
    port_ = socket_.local-address.port
    server_ = http.Server --max-tasks=1
    ready := monitor.Latch
    task_ = task::
      ready.set true
      server_.listen socket_:: | request/http.RequestIncoming writer/http.ResponseWriter |
        handle_ request writer
    ready.get

  /**
  Stops the server. Safe to call multiple times.
  */
  close -> none:
    if server_:
      server_.close
      server_ = null
    if socket_:
      catch: socket_.close
      socket_ = null
    if network:
      network.close
      network = null
    if task_:
      task_.cancel
      task_ = null

  /**
  Returns the port the server is listening on.
  */
  port -> int:
    return port_

  /**
  Returns "http://localhost:<port>", the value to pass as `--base-path` to
    the generated client's `ApiClient`.
  */
  base-path -> string:
    return "http://localhost:$port_"

  /**
  Configures the canned response for the given $method and $resource.
  */
  on method/string resource/string [block] -> none:
    canned := CannedResponse
    block.call canned
    responses_["$method $resource"] = canned

  /**
  Returns the single recorded request. Asserts that exactly one request
    was recorded.
  */
  only-request -> RecordedRequest:
    if recorded.size != 1: throw "expected exactly one recorded request, got $recorded.size"
    return recorded[0]

  handle_ request/http.RequestIncoming writer/http.ResponseWriter -> none:
    body := request.body.read-all
    body-bytes := body or #[]
    query-string := request.query
    recorded.add (RecordedRequest
        --method=request.method
        --path=request.path
        --resource=query-string.resource
        --query=query-string.parameters
        --headers=request.headers
        --body=body-bytes)

    canned/CannedResponse? := responses_.get "$request.method $query-string.resource"
    if not canned: canned = CannedResponse
    canned.headers.do: | key/string value/string |
      writer.headers.set key value
    writer.write-headers canned.status
    if canned.body.size > 0:
      writer.out.write canned.body
    writer.close

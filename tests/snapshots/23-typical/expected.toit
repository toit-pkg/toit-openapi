import http
import net
import openapi-runtime
import .models
import encoding.json

class Api extends openapi-runtime.ApiBase:
  pets-api_/PetsApi? := null
  status-api_/StatusApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    super api-client


  constructor network/net.Client --authentication/openapi-runtime.Authentication?=null --api-key/string?=null:
    client := openapi-runtime.ApiClient network
        --base-path="https://api.example.com/v1"
        --authentication=authentication
    if api-key:
      client.put-authentication "api_key" (openapi-runtime.ApiKeyAuth --location="header"
          --param-name="X-API-KEY"
          --api-key=api-key)
    super client

  pets-api -> PetsApi:
    if (not pets-api_):
      pets-api_ = PetsApi api-client
    return pets-api_

  status-api -> StatusApi:
    if (not status-api_):
      status-api_ = StatusApi api-client
    return status-api_


class PetsApi:
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient:
    api-client_ = client

  list-pets --raw/True --kind/string?=null --limit/int?=null -> http.Response:
    path := "/pets"
    headers := http.Headers
    query-params := []
    cookie-params := []
    if (kind != null):
      query-params.add-all (openapi-runtime.encode-query-param "kind" kind)
    if (limit != null):
      query-params.add-all (openapi-runtime.encode-query-param "limit" limit)
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null
        --security=[["api_key"]]

  /**
  Lists all pets, optionally filtered.
  - $kind: 
  - $limit: 
  */
  list-pets --kind/string?=null --limit/int?=null -> List:
    response := list-pets --raw
        --kind=kind
        --limit=limit
    decoded := json.decode response.body.read-all
    return decoded.map: | it |
      Pet.from-json it

  create-pet --raw/True body/Pet -> http.Response:
    path := "/pets"
    headers := http.Headers
    query-params := []
    cookie-params := []
    headers.set "Content-Type" "application/json"
    return api-client_.invoke-api --path=path
        --method="POST"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null
        --security=[["api_key"]]
        --body=json.encode body.to-json

  /** Creates a pet. */
  create-pet body-1/Pet -> Pet:
    response := create-pet --raw body-1
    return Pet.from-json (json.decode response.body.read-all)

  get-pet --raw/True --pet-id/int --x-trace-id/string?=null -> http.Response:
    path := "/pets/{petId}"
    headers := http.Headers
    query-params := []
    cookie-params := []
    path = path.replace --all
        "{petId}"
        (openapi-runtime.encode-path-param "petId" pet-id)
    if (x-trace-id != null):
      openapi-runtime.encode-header-param headers "X-Trace-Id" x-trace-id
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null
        --security=[["api_key"]]

  /**
  Fetches one pet by id.
  - $pet-id: 
  - $x-trace-id: 
  */
  get-pet --pet-id/int --x-trace-id/string?=null -> Pet:
    response := get-pet --raw
        --pet-id=pet-id
        --x-trace-id=x-trace-id
    return Pet.from-json (json.decode response.body.read-all)


class StatusApi:
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient:
    api-client_ = client

  health --raw/True -> http.Response:
    path := "/health"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  /** Public health check. */
  health:
    health --raw
    return null



import http
import net
import openapi-runtime
import .models
import encoding.json

class Api:
  api-client_/openapi-runtime.ApiClient? := ?
  store-api_/StoreApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    api-client_ = api-client


  constructor network/net.Client --authentication/openapi-runtime.Authentication?=null:
    api-client_ = openapi-runtime.ApiClient network
        --base-path=""
        --authentication=authentication

  close:
    if (not api-client_):
      return
    api-client_.close
    api-client_ = null

  store-api -> StoreApi:
    if (not store-api_):
      store-api_ = StoreApi api-client_
    return store-api_


class StoreApi:
  authentication/openapi-runtime.Authentication? := null
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient --auth/openapi-runtime.Authentication?=null:
    api-client_ = client
    authentication = auth

  get-inventory --raw/True -> http.Response:
    path := "/inventory"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null
        --authentication=authentication

  get-inventory -> Map:
    response := get-inventory --raw
    return json.decode response.body.read-all

  get-pet-index --raw/True -> http.Response:
    path := "/pet-index"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null
        --authentication=authentication

  get-pet-index -> Map:
    response := get-pet-index --raw
    decoded := json.decode response.body.read-all
    return decoded.map: | _ v |
      Pet.from-json v



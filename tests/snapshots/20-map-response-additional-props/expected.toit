import http
import net
import openapi-runtime
import .models as models
import encoding.json

class Api extends openapi-runtime.ApiBase:
  store-api_/StoreApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    super api-client


  constructor network/net.Client --authentication/openapi-runtime.Authentication?=null:
    client := openapi-runtime.ApiClient network
        --base-path=""
        --authentication=authentication
    super client

  store-api -> StoreApi:
    if (not store-api_):
      store-api_ = StoreApi api-client
    return store-api_


class StoreApi:
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient:
    api-client_ = client

  /** Variant of $(get-inventory) that returns the raw HTTP response. */
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

  get-inventory -> Map:
    response := get-inventory --raw
    return json.decode response.body.read-all

  /** Variant of $(get-pet-index) that returns the raw HTTP response. */
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

  get-pet-index -> Map:
    response := get-pet-index --raw
    return (json.decode response.body.read-all).map: | _ v |
      models.Pet.from-json v



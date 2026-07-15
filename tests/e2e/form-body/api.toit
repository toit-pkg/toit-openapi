import http
import net
import openapi-runtime
import .models as models

class Api extends openapi-runtime.ApiBase:
  items-api_/ItemsApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    super api-client


  constructor network/net.Client --authentication/openapi-runtime.Authentication?=null:
    client := openapi-runtime.ApiClient network
        --base-path=""
        --authentication=authentication
    super client

  items-api -> ItemsApi:
    if (not items-api_):
      items-api_ = ItemsApi api-client
    return items-api_


class ItemsApi:
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient:
    api-client_ = client

  /** Variant of $(login body) that returns the raw HTTP response. */
  login --raw/True body/Map -> http.Response:
    path := "/login"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="POST"
        --query-params=query-params
        --header-params=headers
        --form-params=body
        --content-type="application/x-www-form-urlencoded"

  login body/Map:
    login --raw body
    return null

  /** Variant of $(register body) that returns the raw HTTP response. */
  register --raw/True body/models.Credentials -> http.Response:
    path := "/register"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="POST"
        --query-params=query-params
        --header-params=headers
        --form-params=body.to-json
        --content-type="application/x-www-form-urlencoded"

  register body/models.Credentials:
    register --raw body
    return null



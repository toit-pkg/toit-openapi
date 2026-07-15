import http
import net
import openapi-runtime

class Api extends openapi-runtime.ApiBase:
  items-api_/ItemsApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    super api-client


  constructor network/net.Client --authentication/openapi-runtime.Authentication?=null --api-key/string?=null --app-id/string?=null --app-key/string?=null --bearer-auth/string?=null:
    client := openapi-runtime.ApiClient network
        --base-path=""
        --authentication=authentication
    if api-key:
      client.put-authentication "api_key" (openapi-runtime.ApiKeyAuth --location="header"
          --param-name="X-API-KEY"
          --api-key=api-key)
    if app-id:
      client.put-authentication "app_id" (openapi-runtime.ApiKeyAuth --location="query"
          --param-name="appId"
          --api-key=app-id)
    if app-key:
      client.put-authentication "app_key" (openapi-runtime.ApiKeyAuth --location="query"
          --param-name="appKey"
          --api-key=app-key)
    if bearer-auth:
      client.put-authentication "bearer_auth" (openapi-runtime.HttpBearerAuth.token bearer-auth)
    super client

  items-api -> ItemsApi:
    if (not items-api_):
      items-api_ = ItemsApi api-client
    return items-api_


class ItemsApi:
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient:
    api-client_ = client

  /** Variant of $(get-secure) that returns the raw HTTP response. */
  get-secure --raw/True -> http.Response:
    path := "/secure"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null
        --security=[["api_key"]]

  get-secure:
    get-secure --raw
    return null

  /** Variant of $(get-both) that returns the raw HTTP response. */
  get-both --raw/True -> http.Response:
    path := "/both"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null
        --security=[["app_id", "app_key"]]

  get-both:
    get-both --raw
    return null

  /** Variant of $(get-optional) that returns the raw HTTP response. */
  get-optional --raw/True -> http.Response:
    path := "/optional"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null
        --security=[[], ["api_key"]]

  get-optional:
    get-optional --raw
    return null

  /** Variant of $(get-public) that returns the raw HTTP response. */
  get-public --raw/True -> http.Response:
    path := "/public"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  get-public:
    get-public --raw
    return null



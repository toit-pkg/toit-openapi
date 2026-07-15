import http
import net
import openapi-runtime
import .models as models
import encoding.json

class Api extends openapi-runtime.ApiBase:
  pets-api_/PetsApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    super api-client


  constructor network/net.Client --authentication/openapi-runtime.Authentication?=null:
    client := openapi-runtime.ApiClient network
        --base-path=""
        --authentication=authentication
    super client

  pets-api -> PetsApi:
    if (not pets-api_):
      pets-api_ = PetsApi api-client
    return pets-api_


class PetsApi:
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient:
    api-client_ = client

  /** Variant of $(list-pets) that returns the raw HTTP response. */
  list-pets --raw/True -> http.Response:
    path := "/pets"
    headers := http.Headers
    query-params := []
    cookie-params := []
    return api-client_.invoke-api --path=path
        --method="GET"
        --query-params=query-params
        --header-params=headers
        --form-params={:}
        --content-type=null

  list-pets -> List:
    response := list-pets --raw
    decoded := json.decode response.body.read-all
    return decoded.map: | it |
      models.Pet.from-json it



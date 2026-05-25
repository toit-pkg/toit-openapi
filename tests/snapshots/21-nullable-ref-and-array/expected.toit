import http
import net
import openapi-runtime
import .models
import encoding.json

class Api:
  api-client_/openapi-runtime.ApiClient? := ?
  pets-api_/PetsApi? := null

  constructor --api-client/openapi-runtime.ApiClient:
    api-client_ = api-client


  constructor network/net.Client:
    api-client_ = openapi-runtime.ApiClient network --base-path=""

  close:
    if (not api-client_):
      return
    api-client_.close
    api-client_ = null

  pets-api -> PetsApi:
    if (not pets-api_):
      pets-api_ = PetsApi api-client_
    return pets-api_


class PetsApi:
  authentication/openapi-runtime.Authentication? := null
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient --auth/openapi-runtime.Authentication?=null:
    api-client_ = client
    authentication = auth

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
        --body=json.encode body.to-json

  create-pet body-1/Pet -> Pet:
    response := create-pet --raw body-1
    return Pet.from-json (json.decode response.body.read-all)



import http
import net
import openapi-runtime

class Api:
  api-client_/openapi-runtime.ApiClient? := ?
  pets-api_/PetsApi? := null
  users-api_/UsersApi? := null

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

  pets-api -> PetsApi:
    if (not pets-api_):
      pets-api_ = PetsApi api-client_
    return pets-api_

  users-api -> UsersApi:
    if (not users-api_):
      users-api_ = UsersApi api-client_
    return users-api_


class PetsApi:
  authentication/openapi-runtime.Authentication? := null
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient --auth/openapi-runtime.Authentication?=null:
    api-client_ = client
    authentication = auth

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
        --authentication=authentication

  list-pets:
    list-pets --raw
    return null


class UsersApi:
  authentication/openapi-runtime.Authentication? := null
  api-client_/openapi-runtime.ApiClient := ?

  constructor client/openapi-runtime.ApiClient --auth/openapi-runtime.Authentication?=null:
    api-client_ = client
    authentication = auth

  list-users --raw/True -> http.Response:
    path := "/users"
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

  list-users:
    list-users --raw
    return null



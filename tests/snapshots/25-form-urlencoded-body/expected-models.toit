import core

class Credentials:
  username/core.string
  password/core.string

  constructor --.username/core.string --.password/core.string:


  constructor.from-json data/core.Map:
    username = data["username"]
    password = data["password"]

  to-json -> core.Map:
    result := {"username": username, "password": password}
    return result



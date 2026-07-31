import core

class Credentials:
  username/string
  password/string

  constructor --.username/string --.password/string:


  constructor.from-json data/Map:
    username = data["username"]
    password = data["password"]

  to-json -> Map:
    result := {"username": username, "password": password}
    return result



import core

class Api:
  version/string

  constructor --.version/string:


  constructor.from-json data/Map:
    version = data["version"]

  to-json -> Map:
    result := {"version": version}
    return result



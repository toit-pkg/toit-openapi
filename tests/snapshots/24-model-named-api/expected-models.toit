import core

class Api:
  version/core.string

  constructor --.version/core.string:


  constructor.from-json data/core.Map:
    version = data["version"]

  to-json -> core.Map:
    result := {"version": version}
    return result



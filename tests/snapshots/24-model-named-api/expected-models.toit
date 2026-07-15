import core

class Api:
  version/string := ?

  constructor.from-json data/Map:
    version = data["version"]

  to-json -> Map:
    return {"version": version}



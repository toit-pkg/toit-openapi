import core

class Owner:
  name/string

  constructor --.name/string:


  constructor.from-json data/Map:
    name = data["name"]

  to-json -> Map:
    result := {"name": name}
    return result


class Pet:
  id/int
  name/string
  tag/string?
  has-tag/bool
  owner/Owner?
  has-owner/bool

  constructor --.id/int --.name/string --.tag/string?=null --.has-tag/bool=false --.owner/Owner?=null --.has-owner/bool=false:


  constructor.from-json data/Map:
    id = data["id"]
    name = data["name"]
    tag = data.get "tag"
    has-tag = data.contains "tag"
    owner = ((data.get "owner") == null) ? null : (Owner.from-json (data.get "owner"))
    has-owner = data.contains "owner"

  to-json -> Map:
    result := {"id": id, "name": name, "tag": tag, "owner": (owner == null) ? null : owner.to-json}
    if (not has-tag):
      result.remove "tag"
    if (not has-owner):
      result.remove "owner"
    return result



import core

class Category:
  id/int?
  has-id/bool
  name/string?
  has-name/bool

  constructor --.id/int?=null --.has-id/bool=false --.name/string?=null --.has-name/bool=false:


  constructor.from-json data/Map:
    id = data.get "id"
    has-id = data.contains "id"
    name = data.get "name"
    has-name = data.contains "name"

  to-json -> Map:
    result := {"id": id, "name": name}
    if (not has-id):
      result.remove "id"
    if (not has-name):
      result.remove "name"
    return result


class Tag:
  name/string?
  has-name/bool

  constructor --.name/string?=null --.has-name/bool=false:


  constructor.from-json data/Map:
    name = data.get "name"
    has-name = data.contains "name"

  to-json -> Map:
    result := {"name": name}
    if (not has-name):
      result.remove "name"
    return result


class Pet:
  id/int
  name/string
  category/Category?
  has-category/bool
  tags/List?
  has-tags/bool

  constructor --.id/int --.name/string --.category/Category?=null --.has-category/bool=false --.tags/List?=null --.has-tags/bool=false:


  constructor.from-json data/Map:
    id = data["id"]
    name = data["name"]
    category = ((data.get "category") == null) ? null : (Category.from-json (data.get "category"))
    has-category = data.contains "category"
    tags = ((data.get "tags") == null) ? null : ((data.get "tags").map: | it |
      Tag.from-json it)
    has-tags = data.contains "tags"

  to-json -> Map:
    result := {"id": id, "name": name, "category": (category == null) ? null : category.to-json, "tags": (tags == null) ? null : (tags.map: | it |
      it.to-json)}
    if (not has-category):
      result.remove "category"
    if (not has-tags):
      result.remove "tags"
    return result



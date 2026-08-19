import core

class Category:
  id/core.int?
  name/core.string?

  constructor --.id/core.int?=null --.name/core.string?=null:


  constructor.from-json data/core.Map:
    id = data.get "id"
    name = data.get "name"

  to-json -> core.Map:
    result := {:}
    if (id != null):
      result["id"] = id
    if (name != null):
      result["name"] = name
    return result


class Tag:
  name/core.string?

  constructor --.name/core.string?=null:


  constructor.from-json data/core.Map:
    name = data.get "name"

  to-json -> core.Map:
    result := {:}
    if (name != null):
      result["name"] = name
    return result


class Pet:
  id/core.int
  name/core.string
  category/Category?
  tags/core.List?

  constructor --.id/core.int --.name/core.string --.category/Category?=null --.tags/core.List?=null:


  constructor.from-json data/core.Map:
    id = data["id"]
    name = data["name"]
    category = ((data.get "category") == null) ? null : (Category.from-json (data.get "category"))
    tags = ((data.get "tags") == null) ? null : ((data.get "tags").map: | it |
      Tag.from-json it)

  to-json -> core.Map:
    result := {"id": id, "name": name}
    if (category != null):
      result["category"] = (category == null) ? null : category.to-json
    if (tags != null):
      result["tags"] = (tags == null) ? null : (tags.map: | it |
        it.to-json)
    return result



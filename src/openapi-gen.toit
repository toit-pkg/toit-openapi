// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the LICENSE file.

import encoding.yaml
import fs
import host.directory
import host.file
import json-schema
import json-schema.gen as schema-gen
import json-schema.schema as json-schema
import json-schema.action as schema-action
import system
import toit-gen
import toit-gen.namer

import .openapi

// Toit packages referenced from generated code. Each $toit-gen.Package
// carries its identifying URL plus the prefix used in the generated
// `import`s and `package.yaml`.
HTTP-PACKAGE_/toit-gen.Package ::= toit-gen.Package
    --prefix="http"
    --id="github.com/toitlang/pkg-http"
NET-PACKAGE_/toit-gen.Package ::= toit-gen.Package.sdk --prefix="net"
RUNTIME-PACKAGE_/toit-gen.Package ::= toit-gen.Package
    --prefix="openapi-runtime"
    --id="github.com/toitware/toit-openapi-runtime"
ENCODING-PACKAGE_/toit-gen.Package ::= toit-gen.Package.sdk --prefix="encoding"

/**
Wire shape of a value sent over `application/json`.

Drives JSON-encode of request bodies and JSON-decode of responses.
  Independent of the formal Toit type ($TypeResolver.resolve), because Toit
  has no generics so a `List` of `Pet` and a `List` of `string` share the
  same formal type but need different wire handling.

Recursive: $LIST and $TYPED-MAP shapes hold an inner $WireShape_ in
  $element, so `type: array, items: { $ref: Pet }` becomes
  `LIST { element = MODEL Pet }`, and `type: object, additionalProperties:
  { type: array, items: { $ref: Pet } }` nests further.
*/
class WireShape_:
  /// Primitive, byte array, untyped Map/List, or anything we don't model
  /// (e.g. `oneOf`). $encode and $decode return the input unchanged.
  static PASSTHROUGH ::= 0

  /// `$ref` to a generated `models.toit` class. Encode via `expr.to-json`,
  /// decode via `Class.from-json expr`.
  static MODEL ::= 1

  /// `type: array` with a known element shape. Encode/decode walk via
  /// `expr.map: | it | …`.
  static LIST ::= 2

  /// `type: object` with `additionalProperties` and no named `properties`
  /// — i.e. a uniformly-typed map. Walks via `expr.map: | _ v | …`.
  static TYPED-MAP ::= 3

  kind/int

  /// For $MODEL: the (Imported)Ref to the model class. Used both as the
  /// callee for `Class.from-json` and as the formal return type of the
  /// regular variant.
  model-ref/toit-gen.Ref? := null

  /// For $LIST and $TYPED-MAP: the shape of one element.
  element/WireShape_? := null

  constructor --.kind --.model-ref=null --.element=null:

  /**
  True iff $encode and $decode build a non-trivial expression.

  $PASSTHROUGH always returns false; $LIST and $TYPED-MAP return true
    only when their element does. Used to short-circuit `expr.map` chains
    when the recursion would just reproduce the input.
  */
  needs-codec -> bool:
    if kind == PASSTHROUGH: return false
    if kind == MODEL: return true
    return element.needs-codec

  /**
  True iff $encode/$decode emit a `expr.map: | ... |` block.

  Callers use this to decide whether to pull the result into its own
    statement: toit-gen's formatter can't squeeze a block inside a
    parenthesized argument like `json.encode (...)` without breaking
    indentation. $MODEL stays inline because `expr.to-json` is a plain
    call.
  */
  produces-block -> bool:
    if kind == PASSTHROUGH or kind == MODEL: return false
    return needs-codec

  /**
  Builds an expression that converts $expr (a typed value) into its
    JSON-encodable form. Returns $expr unchanged when $needs-codec is
    false.
  */
  encode expr/toit-gen.Expression -> toit-gen.Expression:
    if not needs-codec: return expr
    if kind == MODEL: return toit-gen.Call expr "to-json"
    return walk-collection_ expr: | inner | element.encode inner

  /**
  Mirror of $encode. Builds an expression that converts a JSON-decoded
    value into its typed form.
  */
  decode expr/toit-gen.Expression -> toit-gen.Expression:
    if not needs-codec: return expr
    if kind == MODEL:
      return toit-gen.Call model-ref "from-json" --arguments=[expr]
    return walk-collection_ expr: | inner | element.decode inner

  /**
  Emits `expr.map: | it | <step>` for $LIST or `expr.map: | _ v | <step>`
    for $TYPED-MAP. $step receives the per-element/value reference and
    returns the converted expression.
  */
  walk-collection_ expr/toit-gen.Expression [step] -> toit-gen.Expression:
    if kind == LIST:
      it-def := toit-gen.VarDefinition.it
      inner := step.call (toit-gen.Ref it-def)
      block := toit-gen.Block --parameters=[it-def]
          toit-gen.Statement inner
      return toit-gen.Call expr "map" --arguments=[block]
    if kind == TYPED-MAP:
      value-def := toit-gen.VarDefinition.parameter "v"
      inner := step.call (toit-gen.Ref value-def)
      block := toit-gen.Block --parameters=[toit-gen.VarDefinition.ignored, value-def]
          toit-gen.Statement inner
      return toit-gen.Call expr "map" --arguments=[block]
    throw "walk-collection_ called on non-collection kind=$kind"

/**
Type-and-shape of a decodable JSON response. Populated by
  $ApiGenerator.response-info_ and consumed by $ApiGenerator.build-operation_
  to emit the regular-variant decode + return.
*/
class ResponseInfo_:
  /// Formal Toit type of the regular variant's return — the model class
  /// for `MODEL`, `List` for `LIST`, `Map` for `TYPED-MAP`.
  type/toit-gen.Ref
  shape/WireShape_
  constructor --.type --.shape:

/**
Resolves OpenAPI/JSON-Schema types to $toit-gen.Class instances usable as
  $toit-gen.RefTarget in generated type annotations.

Primitives short-circuit through $simple-type-of_. `$ref` schemas that
  point at a target registered through $models return the generated
  model class (so a body typed as `$ref: '#/components/schemas/Pet'`
  becomes `body/Pet`, with `Pet` defined in `models.toit`).

Schemas that fall through both branches keep today's stub behavior: an
  imported $toit-gen.Class with the hint or fragment-derived name. That
  path covers inline schemas not registered through $models and is the
  thing Phase 4 deliberately leaves alone.
*/
class TypeResolver:
  any-class/toit-gen.Class ::= toit-gen.Class.core "any"
  list-class/toit-gen.Class ::= toit-gen.Class.core "List"
  map-class/toit-gen.Class ::= toit-gen.Class.core "Map"
  byte-array-class/toit-gen.Class ::= toit-gen.Class.core "ByteArray"
  bool-class/toit-gen.Class ::= toit-gen.Class.core "bool"
  int-class/toit-gen.Class ::= toit-gen.Class.core "int"
  num-class/toit-gen.Class ::= toit-gen.Class.core "num"
  string-class/toit-gen.Class ::= toit-gen.Class.core "string"

  /// One $toit-gen.Ref per unique json-schema $Schema, keyed by identity.
  resolved/Map ::= {:}

  /// $schema-gen.Models populated by $ApiGenerator.gen, or null when the
  /// document has no `components.schemas`.
  models/schema-gen.Models? := null

  /// Import emitted into `api.toit` to reach classes in `models.toit`.
  /// Set by $ApiGenerator.gen alongside $models.
  models-import/toit-gen.Import? := null

  /**
  Returns the $toit-gen.Ref to use as the type for $open-api-schema.

  $hint is used as a fallback name when the schema has no nameable URL.
  Refs to classes generated by toit-json-schema are returned as
  $toit-gen.ImportedRef so that `api.toit` correctly imports `models.toit`.
  */
  resolve open-api-schema/Schema? --hint/string -> toit-gen.Ref:
    if not open-api-schema: return toit-gen.Ref any-class
    js/json-schema.Schema := open-api-schema.schema.schema

    if resolved.contains js: return resolved[js]

    simple := simple-type-of_ js
    if simple:
      ref := toit-gen.Ref simple
      resolved[js] = ref
      return ref

    if models and js.is-reference-only:
      target-uri := js.reference-target-uri
      generated := models.lookup-by-uri target-uri
      if generated:
        ref := models-import
            ? (models-import.refer generated)
            : toit-gen.Ref generated
        resolved[js] = ref
        return ref

    name := hint
    if js.is-reference-only:
      target-uri := js.reference-target-uri
      json-schema-name := (target-uri.fragment.split "%2F").last
      name = json-schema-name

    clazz := toit-gen.Class.imported (namer.toit-class-name name)
    ref := toit-gen.Ref clazz
    resolved[js] = ref
    return ref

  simple-type-of_ js/json-schema.Schema -> toit-gen.Class?:
    js.actions.do: | action/schema-action.Action |
      if action is schema-action.Type:
        type-action := action as schema-action.Type
        accepted := type-action.types
        if accepted.size != 1: return null
        type := accepted.first
        if type == "integer": return int-class
        if type == "number": return num-class
        if type == "string": return string-class
        if type == "boolean": return bool-class
        if type == "null": return any-class
        if type == "array": return list-class
        if type == "object": return map-class
        return null
    return null

  /**
  Returns the wire shape for $open-api-schema.

  Independent of $resolve: a list of `Pet` returns a $WireShape_ whose
    kind is $WireShape_.LIST with `element.kind == MODEL`, while $resolve
    on the same schema returns a plain `List` (Toit lacks generics).
    Callers use the shape to decide how to JSON-encode/decode and the
    formal type to declare the parameter.

  Schemas we don't recognize (no `type` action, polymorphic constructs,
    `type: object` with named properties but no generated class, etc.)
    fall through to $WireShape_.PASSTHROUGH — `json.encode` / `json.decode`
    handles those without per-element work.
  */
  shape-of open-api-schema/Schema? -> WireShape_:
    if not open-api-schema:
      return WireShape_ --kind=WireShape_.PASSTHROUGH
    return shape-of-js_ open-api-schema.schema.schema

  shape-of-js_ js/json-schema.Schema -> WireShape_:
    model-ref := model-ref-for_ js
    if model-ref:
      return WireShape_ --kind=WireShape_.MODEL --model-ref=model-ref

    type-action := type-action-of_ js
    if type-action and type-action.types.size == 1:
      type/string := type-action.types.first
      if type == "array":
        items-schema := items-schema-of_ js
        element/WireShape_ := items-schema
            ? shape-of-js_ items-schema
            : (WireShape_ --kind=WireShape_.PASSTHROUGH)
        return WireShape_ --kind=WireShape_.LIST --element=element
      if type == "object":
        // Named properties → not a uniformly-typed map. We'd want MODEL
        // but no class is generated for inline OpenAPI object schemas
        // today, so fall through to PASSTHROUGH.
        if has-named-properties_ js:
          return WireShape_ --kind=WireShape_.PASSTHROUGH
        additional := additional-properties-schema-of_ js
        if additional:
          return WireShape_ --kind=WireShape_.TYPED-MAP
              --element=(shape-of-js_ additional)

    return WireShape_ --kind=WireShape_.PASSTHROUGH

  /**
  Returns the (Imported)Ref to use for a `$ref`-only $js that points at a
    schema registered through $models. Returns null when $js is not a pure
    `$ref` or when the target has no generated class (primitives behind
    `$ref`, schemas in unknown locations).
  */
  model-ref-for_ js/json-schema.Schema -> toit-gen.Ref?:
    if not models or not js.is-reference-only: return null
    target-uri := js.reference-target-uri
    generated := models.lookup-by-uri target-uri
    if not generated: return null
    return models-import
        ? (models-import.refer generated)
        : (toit-gen.Ref generated)

  static type-action-of_ js/json-schema.Schema -> schema-action.Type?:
    js.actions.do: | action/schema-action.Action |
      if action is schema-action.Type: return action as schema-action.Type
    return null

  static items-schema-of_ js/json-schema.Schema -> json-schema.Schema?:
    js.actions.do: | action/schema-action.Action |
      if action is schema-action.Items: return (action as schema-action.Items).items
    return null

  static additional-properties-schema-of_ js/json-schema.Schema -> json-schema.Schema?:
    js.actions.do: | action/schema-action.Action |
      if action is schema-action.Properties: return (action as schema-action.Properties).additional
    return null

  static has-named-properties_ js/json-schema.Schema -> bool:
    js.actions.do: | action/schema-action.Action |
      if action is schema-action.Properties:
        props := (action as schema-action.Properties).properties
        if props and not props.is-empty: return true
    return false

/**
Builds a $toit-gen.Program for a given $OpenApi document.
*/
class ApiGenerator:
  type-resolver/TypeResolver

  // Imports — set up at the start of $gen and used as $RefTarget seeds for
  // every imported symbol via $toit-gen.Import.refer.
  http_/toit-gen.Import? := null
  net_/toit-gen.Import? := null
  runtime_/toit-gen.Import? := null
  /// The document-level `security` requirements; operations without their
  ///   own `security` inherit these.
  document-security_/List? := null  // Of SecurityRequirement.
  /// $api-library_ is captured here so $ensure-json-import_ can lazily add
  ///   `import encoding.json` only when an operation actually needs it.
  api-library_/toit-gen.Library? := null
  json_/toit-gen.Import? := null

  // Stub classes for imported types. They exist purely as $RefTarget; their
  // bodies and members are not generated.
  http-response_/toit-gen.Class ::= toit-gen.Class.imported "Response"
  http-headers_/toit-gen.Class ::= toit-gen.Class.imported "Headers"
  net-client_/toit-gen.Class ::= toit-gen.Class.imported "Client"
  api-client_/toit-gen.Class ::= toit-gen.Class.imported "ApiClient"
  api-base_/toit-gen.Class ::= toit-gen.Class.imported "ApiBase"
  authentication_/toit-gen.Class ::= toit-gen.Class.imported "Authentication"
  api-key-auth_/toit-gen.Class ::= toit-gen.Class.imported "ApiKeyAuth"
  http-bearer-auth_/toit-gen.Class ::= toit-gen.Class.imported "HttpBearerAuth"

  // Free-standing imported names treated as $RefTarget via $VarDefinition.
  encode-query-param_/toit-gen.VarDefinition ::= imported-name_ "encode-query-param"
  encode-header-param_/toit-gen.VarDefinition ::= imported-name_ "encode-header-param"
  encode-path-param_/toit-gen.VarDefinition ::= imported-name_ "encode-path-param"
  /// The `api-client` field inherited from `openapi-runtime.ApiBase`.
  inherited-api-client_/toit-gen.VarDefinition ::= imported-name_ "api-client"
  json-encode_/toit-gen.VarDefinition ::= imported-name_ "encode"
  json-decode_/toit-gen.VarDefinition ::= imported-name_ "decode"

  constructor --.type-resolver:

  /**
  Lazily adds `import encoding.json` to $api-library_ on first use, so a
    spec with no JSON request/response bodies doesn't carry the import.
  */
  ensure-json-import_ -> toit-gen.Import:
    if json_: return json_
    json_ = api-library_.add-import ENCODING-PACKAGE_ --module="json"
    return json_

  /**
  Populates the model library with classes generated from
    `components.schemas.*` and stores the resulting $schema-gen.Models on
    $type-resolver.

  No-op when the document has no `components.schemas`. The model library
    is created only when there is at least one schema to put in it, so a
    schema-less spec generates a single `api.toit` exactly as before.
  */
  populate-models_ openapi/OpenApi
      --program/toit-gen.Program
      --api-library/toit-gen.Library -> none:
    if not openapi.components: return
    schemas := openapi.components.schemas
    if not schemas or schemas.is-empty: return

    json-schemas := []
    schemas.do: | _ schema/Schema |
      json-schemas.add schema.schema

    models-lib := toit-gen.Library "src/models.toit"
    program.libraries.add models-lib
    type-resolver.models = schema-gen.populate program json-schemas
        --library-for-uri=:: models-lib
    // Import with a prefix: an unprefixed `import .models` would pull the
    //   model class names into api.toit's scope, where a schema named like
    //   a generated class (e.g. `Api`) silently shadows it.
    type-resolver.models-import = api-library.add-relative-import "models"
        --preferred-prefix="models"

  /**
  Builds a $toit-gen.VarDefinition that can be used as a RefTarget for an
    imported name (a function or top-level value, not a class).
  */
  static imported-name_ name/string -> toit-gen.VarDefinition:
    vd := toit-gen.VarDefinition.local name --initial=(toit-gen.Literal null)
    vd.name = name
    return vd

  /**
  Generates a $toit-gen.Program for the given $openapi document.

  The returned program contains a single library at "src/api.toit" with a
    main `Api` class plus one per-tag API class.
  */
  gen openapi/OpenApi -> toit-gen.Program:
    program := toit-gen.Program
    library := toit-gen.Library "src/api.toit"
    program.libraries.add library
    api-library_ = library

    // import http
    // import net
    // import openapi-runtime
    http_ = library.add-import HTTP-PACKAGE_
    net_ = library.add-import NET-PACKAGE_
    runtime_ = library.add-import RUNTIME-PACKAGE_

    // Generate model classes for `components.schemas.*` into a sibling
    //   `src/models.toit` library. Cross-library refs from `api.toit`
    //   (e.g. a request body typed as `Pet`) become real types after this.
    populate-models_ openapi --program=program --api-library=library

    // class Api extends openapi-runtime.ApiBase:
    // The `api-client` field, `put-authentication` and `close` are
    //   inherited from the base class.
    api-class := library.add-class "Api"
    api-class.name = "Api"
    api-class.super-class = runtime_.refer api-base_

    document-security_ = openapi.security

    add-api-constructors_ api-class
        --base-path=base-path-of_ openapi
        --security-schemes=security-schemes-of_ openapi

    // Build per-tag classes plus their getters/fields on Api.
    tag-descriptions := {:}
    (openapi.tags or []).do: | tag/Tag |
      tag-descriptions[tag.name] = tag.description

    tag-classes := {:}     // tag-name → toit-gen.Class
    tag-operations := {:}  // tag-name → list of [path, method, Operation]

    openapi.paths.paths.do: | path/string path-item/PathItem |
      PathItem.OPERATION-KINDS.do: | method/string |
        operation := path-item.operation method
        if not operation: continue.do
        tag-name := (operation.tags and not operation.tags.is-empty)
            ? operation.tags.first
            : ""
        ops := tag-operations.get tag-name --init=: []
        ops.add [path, method, operation]

    tag-operations.do: | tag-name/string _ |
      preferred := tag-name == ""
          ? "DefaultApi"
          : "$(namer.toit-class-name tag-name)Api"
      tag-classes[tag-name] = library.add-class preferred

    tag-classes.do: | _ tag-class/toit-gen.Class |
      add-tag-getter_ api-class tag-class inherited-api-client_

    tag-classes.do: | tag-name/string tag-class/toit-gen.Class |
      description := tag-descriptions.get tag-name
      if description: tag-class.toitdoc = [description]
      build-tag-class_ tag-class --operations=tag-operations[tag-name]

    return program

  /**
  The base path to bake into the generated `Api network/net.Client`
    constructor.

  Picks the first `servers[].url` declared on $openapi, defaulting to `""`.
    Multi-server fan-out and `{variable}` substitution are deliberately not
    handled — both can be a later phase, and neither blocks real-world specs
    in practice. URL is passed through verbatim, so absolute URLs and
    relative roots both work.
  */
  static base-path-of_ openapi/OpenApi -> string:
    servers := openapi.servers
    if not servers or servers.is-empty: return ""
    return (servers.first as Server).url

  /**
  Adds the two `Api` constructors:
    - `constructor --api-client/openapi-runtime.ApiClient`
    - `constructor network/net.Client --authentication/openapi-runtime.Authentication?=null`

  The network constructor additionally gets one named string parameter per
    `apiKey` or `http: bearer` scheme in $security-schemes (e.g. `--api-key`
    for a scheme named `api_key`). A given value is registered via
    `put-authentication`, with the scheme's location and parameter name
    baked in from the spec.
  */
  add-api-constructors_ api-class/toit-gen.Class
      --base-path/string
      --security-schemes/Map -> none:
    // constructor --api-client/openapi-runtime.ApiClient:
    //   super api-client
    api-client-param := toit-gen.VarDefinition.parameter "api-client"
        --type=(runtime_.refer api-client_)
        --is-named=true
    api-client-param.name = "api-client"
    body1 := toit-gen.Sequence
    body1.call toit-gen.Super --arguments=[toit-gen.Ref api-client-param]
    api-class.add-constructor --parameters=[api-client-param] body1

    // constructor network/net.Client
    //     --authentication/openapi-runtime.Authentication?=null:
    //   client := openapi-runtime.ApiClient network
    //       --base-path="<servers[0].url>"
    //       --authentication=authentication
    //   <per-scheme put-authentication registrations>
    //   super client
    network-param := toit-gen.VarDefinition.parameter "network"
        --type=(net_.refer net-client_)
    network-param.name = "network"
    auth-param := toit-gen.VarDefinition.parameter "authentication"
        --type=(runtime_.refer authentication_)
        --is-named=true
        --is-nullable=true
        --initial=(toit-gen.Literal null)
    auth-param.name = "authentication"
    scheme-params := []  // Of [VarDefinition, scheme-name/string, SecurityScheme].
    security-schemes.do: | name/string scheme/SecurityScheme |
      is-bearer := scheme.type == SecurityScheme.HTTP
          and (scheme as SecuritySchemeHttp).scheme == "bearer"
      if scheme.type != SecurityScheme.API-KEY and not is-bearer: continue.do
      scheme-param := toit-gen.VarDefinition.parameter (namer.toit-member-name name)
          --type=(toit-gen.Ref type-resolver.string-class)
          --is-named=true
          --is-nullable=true
          --initial=(toit-gen.Literal null)
      scheme-params.add [scheme-param, name, scheme]
    body2 := toit-gen.Sequence
    client-vd := body2.define "client"
        (toit-gen.Call (runtime_.refer api-client_)
            --arguments=[
              toit-gen.Ref network-param,
              toit-gen.Named.external "base-path" (toit-gen.Literal base-path),
              toit-gen.Named.external "authentication" (toit-gen.Ref auth-param),
            ])
    scheme-params.do: | triple/List |
      scheme-param/toit-gen.VarDefinition := triple[0]
      name/string := triple[1]
      scheme/SecurityScheme := triple[2]
      auth-expr/toit-gen.Expression := ?
      if scheme.type == SecurityScheme.API-KEY:
        api-key-scheme := scheme as SecuritySchemeApiKey
        auth-expr = toit-gen.Call (runtime_.refer api-key-auth_)
            --arguments=[
              toit-gen.Named.external "location" (toit-gen.Literal api-key-scheme.in),
              toit-gen.Named.external "param-name" (toit-gen.Literal api-key-scheme.name),
              toit-gen.Named.external "api-key" (toit-gen.Ref scheme-param),
            ]
      else:
        auth-expr = toit-gen.Call (runtime_.refer http-bearer-auth_) "token"
            --arguments=[toit-gen.Ref scheme-param]
      register := toit-gen.Sequence
      register.invoke (toit-gen.Ref client-vd) "put-authentication"
          --arguments=[toit-gen.Literal name, auth-expr]
      body2.iff (toit-gen.Ref scheme-param) register
    body2.call toit-gen.Super --arguments=[toit-gen.Ref client-vd]
    ctor-params := [network-param, auth-param]
    scheme-params.do: | triple/List | ctor-params.add triple[0]
    api-class.add-constructor --parameters=ctor-params body2

  /**
  The `components.securitySchemes` of $openapi, keyed by scheme name.

  References are skipped: constructor convenience needs the scheme's
    metadata (location, parameter name) at generation time.
  */
  static security-schemes-of_ openapi/OpenApi -> Map:
    components := openapi.components
    if not components or not components.security-schemes: return {:}
    result := {:}
    components.security-schemes.do: | name/string scheme |
      if scheme is SecurityScheme: result[name] = scheme
    return result

  /**
  Adds the lazy-init field + getter on `Api` for one per-tag API class:

  ```
  pets-api_/PetsApi? := null
  pets-api -> PetsApi:
    if not pets-api_: pets-api_ = PetsApi api-client
    return pets-api_
  ```
  */
  add-tag-getter_ api-class/toit-gen.Class
      tag-class/toit-gen.Class
      api-client-field/toit-gen.VarDefinition -> none:
    name := tag-class.preferred-name  // E.g. "PetsApi".
    // pets-api_/PetsApi? := null
    field := api-class.add-field name
        --type=(toit-gen.Ref tag-class)
        --is-nullable=true
        --is-final=false
        --is-private=true
        --initial=(toit-gen.Literal null)

    // pets-api -> PetsApi:
    //   if not pets-api_: pets-api_ = PetsApi api-client_
    //   return pets-api_
    body := toit-gen.Sequence
    init := toit-gen.Sequence
    init.assign field
        (toit-gen.Call (toit-gen.Ref tag-class) --arguments=[toit-gen.Ref api-client-field])
    body.iff (toit-gen.Unary "not" (toit-gen.Ref field)) init
    body.ret (toit-gen.Ref field)
    api-class.add-method name --parameters=[] --return-type=(toit-gen.Ref tag-class) body

  /**
  Builds a per-tag class with its constructor and operations.
  */
  build-tag-class_ tag-class/toit-gen.Class --operations/List -> none:
    // api-client_/openapi-runtime.ApiClient
    api-client-field := tag-class.add-field "api-client"
        --type=(runtime_.refer api-client_)
        --is-final=false
        --is-private=true

    // constructor client/openapi-runtime.ApiClient:
    //   api-client_ = client
    client-param := toit-gen.VarDefinition.parameter "client"
        --type=(runtime_.refer api-client_)
    body := toit-gen.Sequence
    body.assign api-client-field (toit-gen.Ref client-param)
    tag-class.add-constructor --parameters=[client-param] body

    operations.do: | entry/List |
      build-operation_ tag-class
          --path=entry[0]
          --method=entry[1]
          --operation=entry[2]
          --api-client-field=api-client-field

  /**
  Builds the two methods (raw + regular variant) for one $operation.
  */
  build-operation_ tag-class/toit-gen.Class
      --path/string
      --method/string
      --operation/Operation
      --api-client-field/toit-gen.VarDefinition -> none:
    op-name := operation.operation-id
        ? namer.toit-member-name operation.operation-id
        : namer.toit-member-name "$path-$method"
    parameters := operation.parameters or []
    has-cookie := parameters.any: | p/Parameter | p.in == Parameter.COOKIE

    request-body-type/toit-gen.Ref? := null
    request-body-description/string? := null
    // Non-null iff the body goes out as `application/json` — drives the
    //   `json.encode (shape.encode body)` recursion in $build-operation-body_.
    //   For any other media type, the body parameter is a `ByteArray` that
    //   the runtime passes through verbatim.
    request-body-shape/WireShape_? := null
    if operation.request-body:
      resolved := operation.request-body.resolved-request-body
      request-body-description = resolved.description
      content := resolved.content
      if content.contains "application/json":
        json-schema := content["application/json"].schema
        request-body-type = type-resolver.resolve json-schema
            --hint="$path-$(method)-request-body"
        request-body-shape = type-resolver.shape-of json-schema
      else:
        request-body-type = toit-gen.Ref type-resolver.byte-array-class

    response-info := response-info_ operation --hint="$path-$(method)-response"

    // The operation's `security` overrides the document-level one; an
    //   explicit empty list marks the operation public. The requirement is
    //   emitted as a list of alternatives, each listing the scheme names
    //   that must all be configured (see `resolve-security` in the runtime).
    effective-security/List? := operation.security or document-security_
    security-expr/toit-gen.Expression? := null
    if effective-security and not effective-security.is-empty:
      alternatives := effective-security.map: | requirement/SecurityRequirement |
        toit-gen.ListLiteral (requirement.requirements.keys.map: toit-gen.Literal it)
      security-expr = toit-gen.ListLiteral alternatives

    // VarDefinitions for the formal parameters: built once per variant since
    // an AST node can't appear under two Function nodes.
    fresh-params := :
      parameters.map: | param/Parameter | [param, param-vd_ param --path=path --method=method]

    // --- Raw variant ---
    // op-name --raw [--p1=...] [--p2=...] [body/Body] -> http.Response:
    //   <build-operation-body_>
    raw-flag := raw-flag-vd_
    raw-params := fresh-params.call
    raw-body-arg := request-body-type ? body-vd_ request-body-type : null
    raw-fn-params := [raw-flag]
    raw-params.do: | pair/List | raw-fn-params.add pair[1]
    if raw-body-arg: raw-fn-params.add raw-body-arg

    raw-fn := tag-class.add-method op-name
        --parameters=raw-fn-params
        --return-type=(http_.refer http-response_)
        (build-operation-body_
            --path=path
            --method=method
            --params=raw-params
            --request-body-arg=raw-body-arg
            --request-body-shape=request-body-shape
            --has-cookie=has-cookie
            --api-client-field=api-client-field
            --security-expr=security-expr)
    // The raw variant's toitdoc is set once the regular variant exists, so
    //   it can cross-reference it instead of duplicating the docs.

    // --- Regular variant ---
    // op-name [--p1=...] [--p2=...] [body/Body] [-> ResponseModel]:
    //   <call --raw + optional deserialize-and-return>
    regular-params := fresh-params.call
    regular-body-arg := request-body-type ? body-vd_ request-body-type : null
    regular-fn-params := []
    regular-params.do: | pair/List | regular-fn-params.add pair[1]
    if regular-body-arg: regular-fn-params.add regular-body-arg

    raw-call-args := [toit-gen.Named raw-flag (toit-gen.Literal true)]
    regular-params.do: | pair/List |
      raw-vd := find-matching_ raw-params (pair[0] as Parameter)
      raw-call-args.add (toit-gen.Named raw-vd (toit-gen.Ref pair[1]))
    if regular-body-arg: raw-call-args.add (toit-gen.Ref regular-body-arg)

    regular-body := toit-gen.Sequence
    regular-return-type/toit-gen.Ref? := null
    if response-info:
      // response := op --raw ...
      // [decoded := json.decode response.body.read-all]
      // return <shape.decode>(decoded)
      raw-call := toit-gen.Call (toit-gen.Ref raw-fn) --arguments=raw-call-args
      response-vd := regular-body.define "response" raw-call
      json-imp := ensure-json-import_
      body-bytes := toit-gen.Call
          (toit-gen.Call (toit-gen.Ref response-vd) "body")
          "read-all"
      decoded-expr/toit-gen.Expression := toit-gen.Call
          (json-imp.refer json-decode_)
          --arguments=[body-bytes]
      // Same toit-gen formatter workaround as the request-body path: when
      //   shape.decode emits a `.map: | ... |` block, hoist the decoded
      //   value to its own statement so the block sits at statement level.
      if response-info.shape.produces-block:
        decoded-vd := regular-body.define "decoded" decoded-expr
        decoded-expr = toit-gen.Ref decoded-vd
      regular-body.ret (response-info.shape.decode decoded-expr)
      regular-return-type = response-info.type
    else:
      regular-body.call (toit-gen.Ref raw-fn) --arguments=raw-call-args
      regular-body.ret (toit-gen.Literal null)

    regular-fn := tag-class.add-method op-name
        --parameters=regular-fn-params
        --return-type=regular-return-type
        regular-body
    regular-fn.toitdoc = build-toitdoc_ operation
        --params=regular-params
        --request-body-arg=regular-body-arg
        --request-body-description=request-body-description

    raw-toitdoc := []
    if operation.deprecated: raw-toitdoc.add "Deprecated.\n\n"
    raw-toitdoc.add "Variant of "
    // The regular variant shares the raw variant's name, so an exact
    //   (full-signature) reference is needed for the link to resolve to it.
    raw-toitdoc.add (toit-gen.ToitdocExactRef regular-fn)
    raw-toitdoc.add " that returns the raw HTTP response."
    raw-fn.toitdoc = raw-toitdoc

  /**
  A formal $toit-gen.VarDefinition for an OpenAPI $Parameter.

  Required → named, non-nullable.  Optional → named, nullable, default `null`.
  */
  param-vd_ param/Parameter --path/string --method/string -> toit-gen.VarDefinition:
    type := type-resolver.resolve param.schema --hint="$path-$method-$param.name"
    if param.required == true:
      return toit-gen.VarDefinition.parameter param.name
          --type=type
          --is-named=true
    return toit-gen.VarDefinition.parameter param.name
        --type=type
        --is-named=true
        --is-nullable=true
        --initial=(toit-gen.Literal null)

  raw-flag-vd_ -> toit-gen.VarDefinition:
    raw := toit-gen.VarDefinition.parameter "raw"
        --type=(toit-gen.Ref (toit-gen.Class.core "True"))
        --is-named=true
    raw.name = "raw"
    return raw

  body-vd_ type/toit-gen.Ref -> toit-gen.VarDefinition:
    return toit-gen.VarDefinition.parameter "body" --type=type

  static find-matching_ pairs/List target-param/Parameter -> toit-gen.VarDefinition:
    pairs.do: | pair/List |
      if (pair[0] as Parameter) == target-param: return pair[1]
    throw "raw parameter not found"

  /**
  Returns the type-and-shape of the operation's first decodable JSON
    response, or null when none is decodable.

  Picks the first 2xx response with an `application/json` content entry;
    falls back to `default`. PASSTHROUGH-shaped schemas (primitives, inline
    `type: object` with no structure we can leverage) are skipped — the
    regular variant returns `null` for those, matching today's behavior.
    LIST and TYPED-MAP responses are kept even when the element shape is
    PASSTHROUGH: the regular variant still returns the decoded `List` /
    `Map` instead of `null`.
  */
  response-info_ operation/Operation --hint/string -> ResponseInfo_?:
    responses := operation.responses
    if not responses: return null
    candidates := []
    responses.responses.do: | code/string r/ResponseOrReference |
      if code.size > 0 and code[0] == '2': candidates.add r
    if responses.default: candidates.add responses.default
    candidates.do: | r/ResponseOrReference |
      response := r.resolved-response
      content := response.content
      if not content: continue.do
      if not content.contains "application/json": continue.do
      schema := content["application/json"].schema
      if not schema: continue.do
      shape := type-resolver.shape-of schema
      if shape.kind == WireShape_.PASSTHROUGH: continue.do
      type := type-resolver.resolve schema --hint=hint
      return ResponseInfo_ --type=type --shape=shape
    return null

  /**
  Builds the body of the raw variant: locals for `path`, `headers`,
    `query-params`, `cookie-params`; per-parameter handling; `headers.set
    "Content-Type"` for JSON bodies; and the final `api-client_.invoke-api`.
  */
  build-operation-body_
      --path/string
      --method/string
      --params/List
      --request-body-arg/toit-gen.VarDefinition?
      --request-body-shape/WireShape_?=null
      --has-cookie/bool
      --api-client-field/toit-gen.VarDefinition
      --security-expr/toit-gen.Expression? -> toit-gen.Sequence:
    body := toit-gen.Sequence
    // path := "<path>"
    // headers := http.Headers
    // query-params := []
    // cookie-params := []
    path-var := body.define "path" (toit-gen.Literal path)
    headers-var := body.define "headers" (toit-gen.Call (http_.refer http-headers_))
    query-var := body.define "query-params" (toit-gen.Literal [])
    cookie-var := body.define "cookie-params" (toit-gen.Literal [])

    // For each parameter, emit the appropriate path/query/header/cookie
    // handling — wrapped in `if param != null:` for optional parameters.
    params.do: | pair/List |
      param/Parameter := pair[0]
      vd/toit-gen.VarDefinition := pair[1]
      branch := toit-gen.Sequence
      append-param-handling_ branch
          --param=param
          --vd=vd
          --path-var=path-var
          --headers-var=headers-var
          --query-var=query-var
          --cookie-var=cookie-var
      if param.required == true:
        branch.statements.do: | stmt/toit-gen.Statement | body.add stmt
      else:
        body.iff
            (toit-gen.Binary (toit-gen.Ref vd) "!=" (toit-gen.Literal null))
            branch

    if has-cookie:
      // headers.set "Cookie" (cookie-params.join "; ")
      join-call := toit-gen.Call (toit-gen.Ref cookie-var) "join"
          --arguments=[toit-gen.Literal "; "]
      body.invoke (toit-gen.Ref headers-var) "set"
          --arguments=[toit-gen.Literal "Cookie", join-call]

    if request-body-arg:
      // headers.set "Content-Type" "application/json"
      body.invoke (toit-gen.Ref headers-var) "set"
          --arguments=[
            toit-gen.Literal "Content-Type",
            toit-gen.Literal "application/json",
          ]

    // return api-client_.invoke-api
    //     --path=path
    //     --method=<METHOD>
    //     --query-params=query-params
    //     --header-params=headers
    //     --form-params={:}
    //     --content-type=null
    //     [--body=body]
    invoke-args := [
      toit-gen.Named.external "path" (toit-gen.Ref path-var),
      toit-gen.Named.external "method" (toit-gen.Literal method.to-ascii-upper),
      toit-gen.Named.external "query-params" (toit-gen.Ref query-var),
      toit-gen.Named.external "header-params" (toit-gen.Ref headers-var),
      toit-gen.Named.external "form-params" (toit-gen.Literal {:}),
      toit-gen.Named.external "content-type" (toit-gen.Literal null),
    ]
    if security-expr:
      invoke-args.add (toit-gen.Named.external "security" security-expr)
    if request-body-arg:
      body-expr/toit-gen.Expression := toit-gen.Ref request-body-arg
      if request-body-shape:
        // application/json: always JSON-encode. shape.encode walks the
        //   wire shape (e.g. for a list of Pet → body.map: it.to-json).
        json-imp := ensure-json-import_
        encoded-form := request-body-shape.encode body-expr
        if request-body-shape.produces-block:
          // toit-gen's formatter can't squeeze a `.map: | it | …` block
          //   inside a parenthesized argument, so we hoist into a local.
          //   See TODO in toit-gen for the formatter fix.
          payload-vd := body.define "payload" encoded-form
          encoded-form = toit-gen.Ref payload-vd
        body-expr = toit-gen.Call (json-imp.refer json-encode_)
            --arguments=[encoded-form]
      invoke-args.add (toit-gen.Named.external "body" body-expr)

    body.ret (toit-gen.Call (toit-gen.Ref api-client-field) "invoke-api" --arguments=invoke-args)
    return body

  append-param-handling_ branch/toit-gen.Sequence
      --param/Parameter
      --vd/toit-gen.VarDefinition
      --path-var/toit-gen.VarDefinition
      --headers-var/toit-gen.VarDefinition
      --query-var/toit-gen.VarDefinition
      --cookie-var/toit-gen.VarDefinition -> none:
    if param.in == Parameter.PATH:
      // path = path.replace --all "{name}"
      //     (openapi-runtime.encode-path-param "name" value [--style=...] [--explode])
      // encode-path-param percent-encodes the value, so the substitution
      //   cannot corrupt the URI.
      args := [toit-gen.Literal param.name, toit-gen.Ref vd]
      if param.style:
        args.add (toit-gen.Named.external "style" (toit-gen.Literal param.style))
      if param.explode:
        args.add (toit-gen.Named.external "explode" (toit-gen.Literal true))
      branch.assign path-var
          (toit-gen.Call (toit-gen.Ref path-var) "replace"
              --arguments=[
                toit-gen.Named.external "all" (toit-gen.Literal true),
                toit-gen.Literal "{$param.name}",
                toit-gen.Call (runtime_.refer encode-path-param_) --arguments=args,
              ])
    else if param.in == Parameter.QUERY:
      // query-params.add-all (openapi-runtime.encode-query-param name value [--style=...] [--explode])
      args := [toit-gen.Literal param.name, toit-gen.Ref vd]
      if param.style:
        args.add (toit-gen.Named.external "style" (toit-gen.Literal param.style))
      if param.explode:
        args.add (toit-gen.Named.external "explode" (toit-gen.Literal true))
      branch.invoke (toit-gen.Ref query-var) "add-all"
          --arguments=[toit-gen.Call (runtime_.refer encode-query-param_) --arguments=args]
    else if param.in == Parameter.HEADER:
      // openapi-runtime.encode-header-param headers "name" value
      branch.call (runtime_.refer encode-header-param_)
          --arguments=[
            toit-gen.Ref headers-var,
            toit-gen.Literal param.name,
            toit-gen.Ref vd,
          ]
    else if param.in == Parameter.COOKIE:
      // cookie-params.add "name=$value"
      branch.invoke (toit-gen.Ref cookie-var) "add"
          --arguments=[toit-gen.StringInterpolation ["$param.name=", toit-gen.Ref vd, ""]]

  build-toitdoc_ operation/Operation
      --params/List
      --request-body-arg/toit-gen.VarDefinition?
      --request-body-description/string? -> List?:
    parts := []
    if operation.description: parts.add operation.description
    if operation.deprecated:
      if not parts.is-empty: parts.add "\n\n"
      parts.add "Deprecated."
    params.do: | pair/List |
      param/Parameter := pair[0]
      vd/toit-gen.VarDefinition := pair[1]
      // Undocumented parameters get no toitdoc entry.
      desc := param.description
      if not desc or desc == "": continue.do
      if not parts.is-empty: parts.add "\n"
      parts.add "- "
      parts.add (toit-gen.ToitdocNameRef vd)
      parts.add ": $desc"
    if request-body-arg and request-body-description:
      if not parts.is-empty: parts.add "\n"
      parts.add "- "
      parts.add (toit-gen.ToitdocNameRef request-body-arg)
      parts.add ": $request-body-description"
    return parts.is-empty ? null : parts

main args/List:
  positional := []
  i := 0
  while i < args.size:
    arg := args[i]
    if arg == "--template" or arg == "-t":
      // Backwards-compat shim: accept and ignore the flag so existing
      // invocations don't break. The mustache template is gone.
      i += 2
    else:
      positional.add arg
      i++

  if positional.size != 2:
    print "Usage: openapi-gen <openapi.yaml> <output-dir>"
    return

  spec-path := positional[0]
  output-dir := positional[1]

  openapi := build (yaml.decode (file.read-contents spec-path))

  type-resolver := TypeResolver
  api-gen := ApiGenerator --type-resolver=type-resolver
  program := api-gen.gen openapi
  files := program.gen --in-memory

  src-dir := fs.join output-dir "src"
  directory.mkdir --recursive src-dir
  files.do: | rel-path/string content/string |
    out-path := fs.join output-dir rel-path
    out-dir := fs.dirname out-path
    if not file.is-directory out-dir:
      directory.mkdir --recursive out-dir
    file.write-contents --path=out-path content

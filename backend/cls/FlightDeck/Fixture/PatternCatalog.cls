/// Pattern catalog (feature 002 User Story 4, research R13). Synthetic entities that exercise what
/// web applications do not: the three confirmation grades on non-system objects, a secret field,
/// a self-protection block, an impact provider and a forced concurrent change.
/// <p>Inert unless ^FlightDeck.Install("fixtures") is set on a test install
/// (FlightDeck.Domain.Fixtures). The entities live in the IRIS CSP session of the signed-in user
/// (a process-private global outside a CSP request) and never touch IRIS configuration. They are
/// reached only through the real FlightDeck.API.Entities and FlightDeck.API.Mutations services, via
/// FlightDeck.Domain.Upstream, so the catalog proves the shipped pattern rather than a copy of it.
/// <p>Forced STATE_CHANGED: the list operation accepts <code>drift=&lt;name&gt;</code> (declared as a
/// forwarded parameter), which bumps that entity's Revision as another administrator would.
Class FlightDeck.Fixture.PatternCatalog [ Abstract ]
{

Parameter SESSIONKEY = "FlightDeck.PatternCatalog";

XData EntityTypes [ MimeType = application/json ]
{
{
 "fixtures/catalog-item": {
  "domain": "fixtures",
  "entityType": "catalog-item",
  "label": "Catalog item",
  "section": "pattern",
  "listOperation": "GET /fixture/catalog-items",
  "detailOperation": "GET /fixture/catalog-item",
  "keys": [
   {
    "param": "name",
    "field": "Name"
   }
  ],
  "displayName": "{name}",
  "schema": "CatalogItem",
  "facts": "catalog-item",
  "forwardParams": [
   "drift",
   "reset"
  ],
  "secretFields": [
   "Secret"
  ],
  "markers": [
   {
    "id": "critical",
    "tone": "warning",
    "text": "Critical",
    "when": {
     "op": "equals",
     "path": "object.Critical",
     "value": true
    }
   },
   {
    "id": "protected",
    "tone": "neutral",
    "text": "Protected",
    "when": {
     "op": "equals",
     "path": "object.Protected",
     "value": true
    }
   },
   {
    "id": "disabled",
    "tone": "neutral",
    "text": "Disabled",
    "when": {
     "op": "equals",
     "path": "object.Enabled",
     "value": false
    }
   }
  ],
  "links": [
   "catalog-tags"
  ],
  "mutations": [
   "PUT /fixture/catalog-item",
   "DELETE /fixture/catalog-item",
   "POST /fixture/catalog-tag/grant",
   "POST /fixture/catalog-tag/revoke"
  ]
 }
}
}

XData Mutations [ MimeType = application/json ]
{
{
 "PUT /fixture/catalog-item": {
  "kind": "upsert",
  "entityType": "fixtures/catalog-item",
  "readOperation": "GET /fixture/catalog-item",
  "schema": "CatalogItem",
  "target": "{name}",
  "secretFields": [
   "Secret"
  ],
  "grade": [
   {
    "when": {
     "op": "and",
     "all": [
      {
       "op": "equals",
       "path": "kind",
       "value": "edit"
      },
      {
       "op": "equals",
       "path": "proposed.Enabled",
       "value": false
      }
     ]
    },
    "grade": "reinforced"
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "equals",
     "path": "current.Protected",
     "value": true
    },
    "message": "This catalog item is protected. The pattern refuses to change it."
   }
  ],
  "refusedWhen": {
   "op": "equals",
   "path": "facts.canBeEdited",
   "value": false
  },
  "disabledReason": "The API reports that this item may not be edited."
 },
 "POST /fixture/catalog-tag/grant": {
  "kind": "action",
  "entityType": "fixtures/catalog-item",
  "params": [
   "name",
   "tag"
  ],
  "readOperation": "GET /fixture/catalog-tags",
  "readParams": {
   "name": "{name}"
  },
  "rowKey": [
   {
    "field": "Tag",
    "value": "{tag}"
   }
  ],
  "rowLabel": "tag {tag}",
  "effect": "add",
  "target": "the tag {tag} on {name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "simple"
   }
  ]
 },
 "POST /fixture/catalog-tag/revoke": {
  "kind": "action",
  "entityType": "fixtures/catalog-item",
  "params": [
   "name",
   "tag"
  ],
  "readOperation": "GET /fixture/catalog-tags",
  "readParams": {
   "name": "{name}"
  },
  "rowKey": [
   {
    "field": "Tag",
    "value": "{tag}"
   }
  ],
  "rowLabel": "tag {tag}",
  "effect": "remove",
  "target": "the tag {tag} on {name}",
  "secretFields": [],
  "grade": [
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ]
 },
 "DELETE /fixture/catalog-item": {
  "kind": "delete",
  "entityType": "fixtures/catalog-item",
  "readOperation": "GET /fixture/catalog-item",
  "schema": "CatalogItem",
  "target": "{name}",
  "secretFields": [
   "Secret"
  ],
  "grade": [
   {
    "when": {
     "op": "equals",
     "path": "current.Critical",
     "value": true
    },
    "grade": "maximum",
    "consequence": "This catalog item is critical. Everything that depends on it stops working."
   },
   {
    "when": {
     "op": "true"
    },
    "grade": "reinforced"
   }
  ],
  "selfProtection": [
   {
    "when": {
     "op": "equals",
     "path": "current.Protected",
     "value": true
    },
    "message": "This catalog item is protected. The pattern refuses to change it."
   }
  ],
  "impact": "catalog-impact",
  "impactWhen": {
   "op": "true"
  }
 }
}
}

ClassMethod EntityType(domain As %String, entityType As %String) As %DynamicObject
{
	set found = ##class(FlightDeck.Domain.Descriptor).Load($classname(), "EntityTypes").%Get(domain _ "/" _ entityType)
	quit $select($isobject(found):found, 1:"")
}

ClassMethod Mutation(operationId As %String) As %DynamicObject
{
	set found = ##class(FlightDeck.Domain.Descriptor).Load($classname(), "Mutations").%Get(operationId)
	quit $select($isobject(found):found, 1:"")
}

/// Every catalog operation is available and allowed: the catalog tests the pattern, not privileges.
ClassMethod Capability(operationId As %String) As %DynamicObject
{
	set found = $isobject(..Mutation(operationId)) || ($piece(operationId, " ", 1) = "GET")
	set entry = {"operationId":(operationId), "reason":($select(found:"", 1:"Unknown operation."))}
	do entry.%Set("allowed", found, "boolean")
	do entry.%Set("available", found, "boolean")
	quit entry
}

ClassMethod FieldNames(schema As %String) As %List
{
	quit:schema'="CatalogItem" ""
	quit $listbuild("Name", "Description", "Enabled", "Critical", "Protected", "Secret", "Revision", "Tags")
}

/// Link provider "catalog-tags", parameterised by scope, so the pattern's parameterised panel is
/// exercised where no domain data can hide a gap (feature 003 T075).
ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("catalog-tags", "tags on this item", "out")
	set scope = $select($isobject(params):params.%Get("scope"), 1:"")
	if scope = "" {
		set parameters = [(##class(FlightDeck.Domain.LinkProviders).Parameter("scope", 1, ["all", "critical"]))]
		quit ##class(FlightDeck.Domain.LinkProviders).NeedsParameter(group, parameters, "Choose a scope: the catalog answers per scope, as the official SQL listings answer per namespace.")
	}
	set group.parameters = [(##class(FlightDeck.Domain.LinkProviders).Parameter("scope", 1, ["all", "critical"], scope))]
	do ..Call("GET", "/fixture/catalog-tags", {"name":(entity.keys.name)}, "", .status, .json)
	if status '= 200 {
		set group.state = "undetermined", group.reason = "The catalog could not be read."
		quit group
	}
	set iter = json.result.%GetIterator()
	while iter.%GetNext(, .row) {
		continue:((scope="critical")&&(row.Tag'["critical"))
		do group.items.%Push({"entityType":"catalog-tag", "domain":"fixtures", "displayName":(row.Tag), "keys":{}, "detail":(scope)})
	}
	set group.count = group.items.%Size()
	quit group
}

ClassMethod Impact(provider As %String, current As %DynamicObject) As %DynamicObject
{
	if provider '= "catalog-impact" quit {"state":"undetermined", "summary":"The impact could not be determined.", "reason":("No impact provider "_provider_".")}
	quit {"state":"ok", "summary":"1 synthetic user loses access to this catalog item.", "users":["fixture_catalog_user"], "objects":[]}
}

/// Seed state: one entity per pattern behaviour.
ClassMethod Seed() As %DynamicArray
{
	quit [
		{"Name":"plain-item", "Description":"Edits are a simple confirmation; disabling asks for the name.", "Enabled":true, "Critical":false, "Protected":false, "Secret":"catalog-secret-plain", "Revision":1, "Tags":["reviewed"]},
		{"Name":"critical-item", "Description":"Deleting it is a maximum confirmation.", "Enabled":true, "Critical":true, "Protected":false, "Secret":"catalog-secret-critical", "Revision":1},
		{"Name":"protected-item", "Description":"Self-protection blocks every change.", "Enabled":true, "Critical":false, "Protected":true, "Secret":"catalog-secret-protected", "Revision":1},
		// The object's own capability field, false: the control is disabled with the API's reason and
		// the request is never issued (RN-FD-34). The rule is refusedWhen, so the item below, which
		// carries no such field at all, stays editable — an unknown capability is not a refusal.
		{"Name":"refused-item", "Description":"The API says this one may not be edited.", "Enabled":true, "Critical":false, "Protected":false, "CanBeEdited":false, "Secret":"catalog-secret-refused", "Revision":1}
	]
}

ClassMethod Load() As %DynamicArray
{
	set text = $select($isobject($get(%session)):$get(%session.Data(..#SESSIONKEY)), 1:$get(^||FlightDeck.PatternCatalog))
	quit $select(text="":..Seed(), 1:##class(%DynamicAbstractObject).%FromJSON(text))
}

ClassMethod Save(items As %DynamicArray)
{
	if $isobject($get(%session)) { set %session.Data(..#SESSIONKEY) = items.%ToJSON() } else { set ^||FlightDeck.PatternCatalog = items.%ToJSON() }
}

/// Restores the seed state (unit tests and the catalog's Reset control).
ClassMethod Reset()
{
	if $isobject($get(%session)) { kill %session.Data(..#SESSIONKEY) } else { kill ^||FlightDeck.PatternCatalog }
}

/// The catalog's operations, with the official API's answer shape ({"result": ...}).
ClassMethod Call(method As %String, path As %String, query As %DynamicObject = "", body As %DynamicAbstractObject = "", Output status As %Integer, Output result As %DynamicAbstractObject, Output raw As %String) As %Status
{
	set method = $zconvert(method, "U"), raw = "", result = ""
	if '$isobject(query) set query = {}
	set items = ..Load(), name = query.name
	set index = -1
	set iter = items.%GetIterator()
	while iter.%GetNext(.i, .item) { if (name '= "") && (item.Name = name) set index = i quit }
	if (method = "GET") && (path = "/fixture/catalog-items") {
		if query.reset = "all" do ..Reset() set items = ..Load()
		if query.drift '= "" {
			set iter = items.%GetIterator()
			while iter.%GetNext(, .item) { if item.Name = query.drift set item.Revision = item.Revision + 1 }
			do ..Save(items)
		}
		set status = 200, result = {"result":(items)}
		quit $$$OK
	}
	if path = "/fixture/catalog-tags" {
		if index < 0 set status = 404, raw = "Catalog item "_name_" does not exist." quit $$$OK
		set tags = []
		set item = items.%Get(index)
		if $isobject(item.Tags) {
			set iter = item.Tags.%GetIterator()
			while iter.%GetNext(, .tag) { do tags.%Push({"Tag":(tag)}) }
		}
		set status = 200, result = {"result":(tags)}
		quit $$$OK
	}
	if (path = "/fixture/catalog-tag/grant") || (path = "/fixture/catalog-tag/revoke") {
		if index < 0 set status = 404, raw = "Catalog item "_name_" does not exist." quit $$$OK
		set item = items.%Get(index), tag = query.tag
		if tag = "" set status = 400, raw = "tag is required" quit $$$OK
		if '$isobject(item.Tags) set item.Tags = []
		set kept = []
		set iter = item.Tags.%GetIterator()
		while iter.%GetNext(, .existing) { do:existing'=tag kept.%Push(existing) }
		if path = "/fixture/catalog-tag/grant" do kept.%Push(tag)
		set item.Tags = kept, item.Revision = item.Revision + 1
		do ..Save(items)
		set status = 200, result = {"result":(item)}
		quit $$$OK
	}
	if path '= "/fixture/catalog-item" set status = 404, raw = "Unknown catalog path "_path quit $$$OK
	if method = "GET" {
		if index < 0 set status = 404, result = {"status":{"errors":[{"error":("Catalog item "_name_" does not exist.")}]}} quit $$$OK
		set status = 200, result = {"result":(items.%Get(index))}
		quit $$$OK
	}
	if method = "PUT" {
		if name = "" set status = 400, raw = "name is required" quit $$$OK
		if index < 0 {
			set item = {"Name":(name), "Revision":1}
			do items.%Push(item)
			set status = 201
		} else {
			set item = items.%Get(index), item.Revision = item.Revision + 1
			set status = 200
		}
		if $isobject(body) {
			set fields = body.%GetIterator()
			while fields.%GetNext(.field, .value) {
				continue:(field="Name")||(field="Revision")
				set type = body.%GetTypeOf(field)
				if $listfind($listbuild("boolean", "number", "null"), type) { do item.%Set(field, value, type) } else { do item.%Set(field, value) }
			}
		}
		do ..Save(items)
		set result = {"result":(item)}
		quit $$$OK
	}
	if method = "DELETE" {
		if index < 0 set status = 404, raw = "Catalog item "_name_" does not exist." quit $$$OK
		do items.%Remove(index)
		do ..Save(items)
		set status = 200, result = {}
		quit $$$OK
	}
	set status = 405, raw = "Method "_method_" is not supported by the catalog."
	quit $$$OK
}

}

/// Generic entity reads driven by entity-type descriptors (feature 002 research R3). Every read goes
/// through FlightDeck.Domain.Upstream to the official operation the descriptor names; official objects
/// are returned unchanged, with FlightDeck metadata beside them.
Class FlightDeck.Domain.Entity [ Abstract ]
{

Parameter MAXROWS = 1000;

/// Official path of an operationId ("GET /v2/web-apps" -> "/v2/web-apps").
ClassMethod Path(operationId As %String) As %String
{
	quit $piece(operationId, " ", 2, *)
}

/// Keys object {param: value} from an official list item.
ClassMethod KeysFromItem(type As %DynamicObject, item As %DynamicObject) As %DynamicObject
{
	set keys = {}
	set iter = type.keys.%GetIterator()
	while iter.%GetNext(, .key) { do keys.%Set(key.param, item.%Get(key.field)) }
	quit keys
}

/// Keys object from request data; missing is set to the first missing parameter name.
ClassMethod KeysFromRequest(type As %DynamicObject, Output missing As %String) As %DynamicObject
{
	set keys = {}, missing = ""
	set iter = type.keys.%GetIterator()
	while iter.%GetNext(, .key) {
		set value = $get(%request.Data(key.param, 1))
		if value = "" set:missing="" missing = key.param
		do keys.%Set(key.param, value)
	}
	quit keys
}

ClassMethod DisplayName(type As %DynamicObject, keys As %DynamicObject) As %String
{
	set text = type.displayName
	set iter = keys.%GetIterator()
	while iter.%GetNext(.param, .value) { set text = $replace(text, "{"_param_"}", value) }
	quit text
}

/// Markers whose predicate holds, with the first matching text variant.
/// <p>A marker text may name a value: "{facts.daysRemaining}" or "{object.Name}". The value is
/// substituted from the same context the predicate saw, so "Expires in 12 days" is data, not a
/// second source of truth in a screen (feature 003 contract ui-pattern-delta D6).
ClassMethod Markers(type As %DynamicObject, object As %DynamicObject, facts As %DynamicObject) As %DynamicArray
{
	set out = []
	quit:'type.%IsDefined("markers") out
	set ctx = {"object":(object), "facts":(facts)}
	set iter = type.markers.%GetIterator()
	while iter.%GetNext(, .marker) {
		continue:'##class(FlightDeck.Domain.Predicate).Eval(marker.when, ctx)
		set text = marker.text
		if marker.%IsDefined("variants") {
			set variants = marker.variants.%GetIterator()
			while variants.%GetNext(, .variant) {
				if ##class(FlightDeck.Domain.Predicate).Eval(variant.when, ctx) set text = variant.text quit
			}
		}
		do out.%Push({"id":(marker.id), "text":(..Interpolate(text, ctx)), "tone":(marker.tone)})
	}
	quit out
}

/// Replaces "{facts.x}" and "{object.y}" in a marker text with the value from the context.
ClassMethod Interpolate(text As %String, ctx As %DynamicObject) As %String
{
	quit:'(text [ "{") text
	for i=2:2:$length(text, "{") {
		set token = $piece($piece(text, "{", i), "}", 1)
		continue:token=""
		if ##class(FlightDeck.Domain.Predicate).Resolve(ctx, token, .value) {
			set text = $replace(text, "{"_token_"}", value)
		}
	}
	quit text
}

/// Calls the official list operation. Returns the items or "" with status/json/raw describing the
/// failure.
ClassMethod List(type As %DynamicObject, query As %DynamicObject, Output status As %Integer, Output json As %DynamicAbstractObject, Output raw As %String) As %DynamicArray
{
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", ..Path(type.listOperation), query, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc) quit ""
	quit:status'=200 ""
	quit $select($isobject(json) && $isobject(json.result):json.result, 1:[])
}

/// The official list item whose keys match, for facts that only the list carries (for example
/// IsSystemApp and Type of a web application). "" when the type has no list or nothing matches.
ClassMethod ListItemFor(type As %DynamicObject, keys As %DynamicObject) As %DynamicObject
{
	quit:'type.%IsDefined("listOperation") ""
	set query = {"maxRows":(..#MAXROWS)}
	set op = ##class(FlightDeck.Capability.Map).Operation(type.listOperation)
	if $isobject(op) && op.hasFilter {
		set first = type.keys.%Get(0).param
		set query.filter = keys.%Get(first)
	}
	set items = ..List(type, query, .status)
	quit:'$isobject(items) ""
	set iter = items.%GetIterator(), found = ""
	while iter.%GetNext(, .item) {
		set match = 1
		set k = type.keys.%GetIterator()
		while k.%GetNext(, .key) { if item.%Get(key.field) '= keys.%Get(key.param) set match = 0 quit }
		if match set found = item quit
	}
	quit found
}

/// Reads one entity: the official detail object plus list item, facts and markers.
/// Returns "" with status/json/raw describing the failure.
ClassMethod Read(type As %DynamicObject, keys As %DynamicObject, Output status As %Integer, Output json As %DynamicAbstractObject, Output raw As %String) As %DynamicObject
{
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", ..Path(type.detailOperation), keys, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc) quit ""
	quit:status'=200 ""
	set object = $select($isobject(json) && $isobject(json.result):json.result, 1:{})
	do ..RemoveSecrets(type, object)
	set listItem = $select(type.facts'="":..ListItemFor(type, keys), type.markers.%Size()>0:..ListItemFor(type, keys), 1:"")
	// Facts see the detail plus whatever only the list carries (IsSystemApp and Type for a web
	// application, for example). The detail wins: it is the object the user is looking at.
	set basis = ..Merge(object, listItem)
	set facts = ##class(FlightDeck.Domain.Facts).For(type.facts, basis)
	set entity = {"entityType":(type.entityType), "keys":(keys), "displayName":(..DisplayName(type, keys)), "object":(object), "facts":(facts)}
	set entity.listItem = $select($isobject(listItem):listItem, 1:{})
	do entity.%Set("isSystem", ''facts.system || ''basis.System, "boolean")
	do entity.%Set("isFlightDeck", ''facts.flightDeck, "boolean")
	set entity.markers = ..Markers(type, basis, facts)
	quit entity
}

/// A copy of the detail object with the list item's extra fields added (never overwriting).
ClassMethod Merge(object As %DynamicObject, listItem As %DynamicObject) As %DynamicObject
{
	quit:'$isobject(listItem) object
	set merged = ##class(%DynamicAbstractObject).%FromJSON(object.%ToJSON())
	set iter = listItem.%GetIterator()
	while iter.%GetNext(.field, .value) {
		continue:merged.%IsDefined(field)
		set type = listItem.%GetTypeOf(field)
		if $listfind($listbuild("boolean", "number", "null"), type) { do merged.%Set(field, value, type) } else { do merged.%Set(field, value) }
	}
	quit merged
}

/// Descriptor-declared secret fields never leave the server (Constitution VI).
ClassMethod RemoveSecrets(type As %DynamicObject, object As %DynamicObject)
{
	quit:'type.%IsDefined("secretFields")
	set iter = type.secretFields.%GetIterator()
	while iter.%GetNext(, .field) { do object.%Remove(field) }
}

/// Writes a failed official answer as the FlightDeck error envelope, keeping the IRIS text.
ClassMethod WriteFailure(operationId As %String, status As %Integer, json As %DynamicAbstractObject, raw As %String) As %Status
{
	if status = 403 {
		set op = ##class(FlightDeck.Capability.Map).Operation(operationId)
		set requires = $select($isobject(op):op.requires, 1:[])
		// The official 403 carries no error text: raw is kept only when IRIS said something.
		set text = ##class(FlightDeck.Admin.Client).ErrorText(json, raw)
		quit ##class(FlightDeck.API.Response).WriteError(403, "FORBIDDEN", ##class(FlightDeck.API.Response).RequiresMessage(requires), $select(text=raw:"", 1:text), requires)
	}
	if status = 501 {
		quit ##class(FlightDeck.API.Response).WriteError(501, "UNAVAILABLE", ##class(FlightDeck.Admin.Client).UnavailableReason(operationId))
	}
	quit ##class(FlightDeck.API.Response).WriteError($select(status>=400:status, 1:502), "UPSTREAM_REJECTED", ##class(FlightDeck.Admin.Client).ErrorText(json, raw), raw)
}

}

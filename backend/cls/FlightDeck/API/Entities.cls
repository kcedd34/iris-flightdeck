/// GET /v1/domains/:domain/:entityType, /item and /links (feature 002 contract). Descriptor-driven
/// reads of official objects; see FlightDeck.Domain.Entity.
Class FlightDeck.API.Entities [ Abstract ]
{

ClassMethod List(domain As %String, entityType As %String) As %Status
{
	set type = ##class(FlightDeck.Domain.Descriptor).EntityType(domain, entityType)
	if '$isobject(type) || 'type.%IsDefined("listOperation") {
		quit ##class(FlightDeck.API.Response).WriteError(404, "NOT_FOUND", "No list for "_domain_"/"_entityType_".")
	}
	set maxRows = +$get(%request.Data("maxRows", 1))
	set:(maxRows<=0)||(maxRows>##class(FlightDeck.Domain.Entity).#MAXROWS) maxRows = ##class(FlightDeck.Domain.Entity).#MAXROWS
	set query = {"maxRows":(maxRows)}
	set op = ##class(FlightDeck.Capability.Map).Operation(type.listOperation)
	if $isobject(op) && op.hasFilter && ($get(%request.Data("filter", 1)) '= "") set query.filter = %request.Data("filter", 1)
	if type.%IsDefined("forwardParams") {
		set iter = type.forwardParams.%GetIterator()
		while iter.%GetNext(, .param) { if $get(%request.Data(param, 1)) '= "" do query.%Set(param, %request.Data(param, 1)) }
	}
	set items = ##class(FlightDeck.Domain.Entity).List(type, query, .status, .json, .raw)
	if '$isobject(items) quit ##class(FlightDeck.Domain.Entity).WriteFailure(type.listOperation, status, json, raw)
	set out = []
	set iter = items.%GetIterator()
	while iter.%GetNext(, .item) {
		set keys = ##class(FlightDeck.Domain.Entity).KeysFromItem(type, item)
		set facts = ##class(FlightDeck.Domain.Facts).For(type.facts, item)
		set markers = ##class(FlightDeck.Domain.Entity).Markers(type, item, facts)
		do ##class(FlightDeck.Domain.Entity).RemoveSecrets(type, item)
		do out.%Push({
			"object":(item), "keys":(keys), "facts":(facts),
			"displayName":(##class(FlightDeck.Domain.Entity).DisplayName(type, keys)),
			"markers":(markers)
		})
	}
	set response = {"entityType":(type.entityType), "operationId":(type.listOperation), "items":(out), "total":(out.%Size())}
	do response.%Set("capped", out.%Size() >= maxRows, "boolean")
	quit ##class(FlightDeck.API.Response).WriteJSON(response)
}

ClassMethod Item(domain As %String, entityType As %String) As %Status
{
	set type = ##class(FlightDeck.Domain.Descriptor).EntityType(domain, entityType)
	if '$isobject(type) quit ##class(FlightDeck.API.Response).WriteError(404, "NOT_FOUND", "Unknown entity type "_domain_"/"_entityType_".")
	set keys = ##class(FlightDeck.Domain.Entity).KeysFromRequest(type, .missing)
	if missing '= "" quit ##class(FlightDeck.API.Response).WriteError(400, "MISSING_KEY", "Query parameter '"_missing_"' is required.")
	set entity = ##class(FlightDeck.Domain.Entity).Read(type, keys, .status, .json, .raw)
	if '$isobject(entity) quit ##class(FlightDeck.Domain.Entity).WriteFailure(type.detailOperation, status, json, raw)
	set mutations = []
	if type.%IsDefined("mutations") {
		set iter = type.mutations.%GetIterator()
		while iter.%GetNext(, .operationId) {
			set entry = ##class(FlightDeck.Capability.Map).CurrentEntry(operationId)
			set capability = {"operationId":(operationId), "reason":(entry.reason)}
			do capability.%Set("allowed", ''entry.allowed, "boolean")
			do capability.%Set("available", ''entry.available, "boolean")
			do mutations.%Push(capability)
		}
	}
	set response = {
		"entityType":(entity.entityType), "object":(entity.object), "keys":(keys),
		"displayName":(entity.displayName), "markers":(entity.markers), "facts":(entity.facts), "availableMutations":(mutations)
	}
	do response.%Set("isSystem", entity.isSystem, "boolean")
	do response.%Set("isFlightDeck", entity.isFlightDeck, "boolean")
	quit ##class(FlightDeck.API.Response).WriteJSON(response)
}

ClassMethod Links(domain As %String, entityType As %String) As %Status
{
	set type = ##class(FlightDeck.Domain.Descriptor).EntityType(domain, entityType)
	if '$isobject(type) quit ##class(FlightDeck.API.Response).WriteError(404, "NOT_FOUND", "Unknown entity type "_domain_"/"_entityType_".")
	set keys = ##class(FlightDeck.Domain.Entity).KeysFromRequest(type, .missing)
	if missing '= "" quit ##class(FlightDeck.API.Response).WriteError(400, "MISSING_KEY", "Query parameter '"_missing_"' is required.")
	set entity = ##class(FlightDeck.Domain.Entity).Read(type, keys, .status, .json, .raw)
	if '$isobject(entity) quit ##class(FlightDeck.Domain.Entity).WriteFailure(type.detailOperation, status, json, raw)
	quit ##class(FlightDeck.API.Response).WriteJSON({"groups":(..Groups(type, entity, $get(%request.Data("provider", 1)), ..Parameters()))})
}

/// Query parameters a provider may declare (feature 003 D2). Everything the request carries that is
/// not an entity key is offered to the providers; each one reads only what it declared.
ClassMethod Parameters() As %DynamicObject
{
	set params = {}
	set name = ""
	for {
		set name = $order(%request.Data(name))
		quit:name=""
		continue:name="provider"
		do params.%Set(name, $get(%request.Data(name, 1)))
	}
	quit params
}

ClassMethod Groups(type As %DynamicObject, entity As %DynamicObject, only As %String = "", params As %DynamicObject = "") As %DynamicArray
{
	set groups = []
	quit:'type.%IsDefined("links") groups
	if '$isobject(params) set params = {}
	set iter = type.links.%GetIterator()
	while iter.%GetNext(, .provider) {
		continue:((only'="")&&(provider'=only))
		set class = ##class(FlightDeck.Domain.LinkProviders).Class(provider)
		continue:class=""
		try {
			set group = $classmethod(class, "Group", entity, params)
		} catch ex {
			set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup(provider, provider)
			set group.state = "undetermined", group.reason = ex.DisplayString()
		}
		if $isobject(group) do groups.%Push(group)
	}
	quit groups
}

}

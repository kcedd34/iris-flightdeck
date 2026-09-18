/// Loader and validator for the declarative descriptors (feature 002 data-model §1):
/// entity types in FlightDeck.Domain.EntityTypes and mutations in FlightDeck.Mutation.Descriptors.
/// <p>A descriptor names official operations and presentation rules. It never states a privilege:
/// privileges always come from the capability map derived from the official specification
/// (Constitution III). <method>Validate</method> enforces that, and
/// scripts/build/check-descriptors.py repeats it offline in the build.
Class FlightDeck.Domain.Descriptor [ Abstract ]
{

/// Keys that would state a privilege. Forbidden anywhere in a descriptor.
Parameter FORBIDDENKEYS = "requires,privilege,privileges,resource,permission,permissions";

ClassMethod EntityTypes() As %DynamicObject
{
	quit ..Load("FlightDeck.Domain.EntityTypes", "EntityTypes")
}

ClassMethod Mutations() As %DynamicObject
{
	quit ..Load("FlightDeck.Mutation.Descriptors", "Mutations")
}

/// The entity type "domain/entityType", or "" when none is declared (fixture types included only
/// when the install enabled fixtures).
ClassMethod EntityType(domain As %String, entityType As %String) As %DynamicObject
{
	set found = ..EntityTypes().%Get(domain _ "/" _ entityType)
	if $isobject(found) quit found
	if ##class(FlightDeck.Domain.Fixtures).Enabled() quit ##class(FlightDeck.Domain.Fixtures).EntityType(domain, entityType)
	quit ""
}

/// The mutation descriptor for an operationId, or "".
ClassMethod Mutation(operationId As %String) As %DynamicObject
{
	set found = ..Mutations().%Get(operationId)
	if $isobject(found) quit found
	if ##class(FlightDeck.Domain.Fixtures).Enabled() quit ##class(FlightDeck.Domain.Fixtures).Mutation(operationId)
	quit ""
}

ClassMethod Load(class As %String, xdataName As %String) As %DynamicObject
{
	set cacheKey = class _ "||" _ xdataName
	if $isobject($get(%FlightDeckDescriptors(cacheKey))) quit %FlightDeckDescriptors(cacheKey)
	set xdata = ##class(%Dictionary.CompiledXData).%OpenId(cacheKey)
	set data = $select($isobject(xdata):##class(%DynamicAbstractObject).%FromJSON(xdata.Data), 1:{})
	set %FlightDeckDescriptors(cacheKey) = data
	quit data
}

/// Validates every shipped descriptor. Returns a %DynamicArray of problems (empty when valid).
ClassMethod Validate(entityTypes As %DynamicObject = "", mutations As %DynamicObject = "") As %DynamicArray
{
	set problems = []
	if '$isobject(entityTypes) set entityTypes = ..EntityTypes()
	if '$isobject(mutations) set mutations = ..Mutations()
	set iter = entityTypes.%GetIterator()
	while iter.%GetNext(.id, .type) {
		do ..Forbidden(type, "entity type "_id, problems)
		for key = "listOperation", "detailOperation" {
			continue:'type.%IsDefined(key)
			do ..KnownOperation(type.%Get(key), "entity type "_id_" "_key, problems)
		}
		// A singleton type identifies one object per instance, so it has no keys by design.
		if ''type.singleton = 0, '$isobject(type.keys) || (type.keys.%Size() = 0) do problems.%Push("entity type "_id_" has no keys")
		if type.%IsDefined("markers") {
			set markers = type.markers.%GetIterator()
			while markers.%GetNext(, .marker) {
				set problem = ##class(FlightDeck.Domain.Predicate).Problem(marker.when, "object,facts")
				if problem '= "" do problems.%Push("entity type "_id_" marker "_marker.id_": "_problem)
			}
		}
		if type.%IsDefined("mutations") {
			set ops = type.mutations.%GetIterator()
			while ops.%GetNext(, .op) {
				// An operation FlightDeck declines to offer has no descriptor by design: the capability
				// map answers for it, with the reason and the native path (feature 003 FR-020).
				continue:##class(FlightDeck.Capability.Policy).Entry(op)'=""
				if '$isobject(mutations.%Get(op)) do problems.%Push("entity type "_id_" names mutation "_op_" without a descriptor")
			}
		}
	}
	set iter = mutations.%GetIterator()
	while iter.%GetNext(.op, .mutation) {
		do ..Forbidden(mutation, "mutation "_op, problems)
		if (mutation.kind '= "request") && (mutation.kind '= "action") {
			do ..KnownOperation(op, "mutation "_op, problems)
			do ..KnownOperation(mutation.readOperation, "mutation "_op_" readOperation", problems)
		}
		if mutation.kind = "action" {
			// An action names an official operation and its declared parameters; its optional listing
			// is an official operation too (feature 003 data-model §5.1).
			do ..KnownOperation(op, "mutation "_op, problems)
			// An action identifies its target with params, or carries only body values (localParams).
			set declared = 0
			for list = "params", "localParams", "optionalParams" {
				set value = mutation.%Get(list)
				if $isobject(value), value.%Size() > 0 set declared = 1
			}
			// A singleton has no keys by design, so an action on it takes no parameters: the object it
			// acts on is the instance itself (feature 004: the task manager, the device settings).
			set onSingleton = 0
			if mutation.%IsDefined("entityType") {
				set target = entityTypes.%Get(mutation.entityType)
				set onSingleton = $isobject(target) && ''target.singleton
			}
			if 'declared, 'onSingleton do problems.%Push("action "_op_" declares no parameters at all")
			if mutation.%IsDefined("readOperation") {
				do ..KnownOperation(mutation.readOperation, "mutation "_op_" readOperation", problems)
				if '$isobject(mutation.rowKey) || (mutation.rowKey.%ClassName(1) '= "%Library.DynamicArray") {
					do problems.%Push("action "_op_" needs a rowKey list of {field, value} pairs")
				}
				if '$listfind($listbuild("add", "remove"), mutation.effect) do problems.%Push("action "_op_" needs effect add or remove")
			}
		}
		if ($listfind($listbuild("delete", "request", "action"), mutation.kind) || mutation.%IsDefined("grade")) && (mutation.target = "") {
			do problems.%Push("mutation "_op_" has no target")
		}
		if mutation.%IsDefined("impactWhen") {
			set problem = ##class(FlightDeck.Domain.Predicate).Problem(mutation.impactWhen, "current,proposed,isSystem,isFlightDeck,facts,request,kind")
			if problem '= "" do problems.%Push("mutation "_op_" impactWhen: "_problem)
		}
		if mutation.%IsDefined("refusedWhen") {
			set problem = ##class(FlightDeck.Domain.Predicate).Problem(mutation.refusedWhen, "current,proposed,isSystem,isFlightDeck,isOwnSession,facts,request,kind,params")
			if problem '= "" do problems.%Push("mutation "_op_" refusedWhen: "_problem)
			if 'mutation.%IsDefined("disabledReason") do problems.%Push("mutation "_op_" declares refusedWhen without disabledReason: a refusal must say why")
		}
		for list = "grade", "selfProtection" {
			continue:'mutation.%IsDefined(list)
			set rules = mutation.%Get(list).%GetIterator()
			while rules.%GetNext(, .rule) {
				set problem = ##class(FlightDeck.Domain.Predicate).Problem(rule.when, "current,proposed,isSystem,isFlightDeck,isOwnSession,facts,request,kind,params")
				if problem '= "" do problems.%Push("mutation "_op_" "_list_": "_problem)
			}
		}
	}
	quit problems
}

ClassMethod KnownOperation(operationId As %String, where As %String, problems As %DynamicArray)
{
	if '$isobject(##class(FlightDeck.Capability.Map).Operation(operationId)) {
		do problems.%Push(where_" names unknown operation '"_operationId_"'")
	}
}

/// Recursively rejects any key that would state a privilege.
ClassMethod Forbidden(node As %DynamicAbstractObject, where As %String, problems As %DynamicArray)
{
	quit:'$isobject(node)
	set iter = node.%GetIterator()
	while iter.%GetNext(.key, .value) {
		if node.%IsA("%DynamicObject"), $listfind($listfromstring(..#FORBIDDENKEYS), $zconvert(key, "L")) {
			do problems.%Push(where_" declares '"_key_"': privileges come only from the capability map")
		}
		if $isobject(value) do ..Forbidden(value, where, problems)
	}
}

}

/// Composite capabilities (feature 002 research R11, data-model §4): what a FlightDeck feature that
/// calls several official operations needs. Derived from the operationIds the descriptors and link
/// providers name, crossed with the capability map; never written by hand (Constitution III).
/// <p>requires is AND across operations, each keeping its own OR list.
Class FlightDeck.Capability.Composite [ Abstract ]
{

/// All composites: per entity type ".list", ".detail", ".links", plus "rest.execute".
ClassMethod Build(privileges As %DynamicObject) As %DynamicArray
{
	set out = []
	set iter = ##class(FlightDeck.Domain.Descriptor).EntityTypes().%GetIterator()
	while iter.%GetNext(.id, .type) {
		if type.%IsDefined("listOperation") do out.%Push(..Entry(id_".list", $listbuild(type.listOperation), privileges))
		do out.%Push(..Entry(id_".detail", $listbuild(type.detailOperation), privileges))
		if type.%IsDefined("links") && (type.links.%Size() > 0) {
			set ops = $listbuild(type.detailOperation)
			set providers = type.links.%GetIterator()
			while providers.%GetNext(, .provider) {
				set class = ##class(FlightDeck.Domain.LinkProviders).Class(provider)
				continue:class=""
				set ops = ops _ $classmethod(class, "Operations")
			}
			do out.%Push(..Entry(id_".links", ops, privileges))
		}
	}
	do out.%Push(..Entry("rest.execute", ..ExecutorOperations(), privileges))
	quit out
}

/// Official operations the REST test executor calls to resolve a target (research R8).
ClassMethod ExecutorOperations() As %List
{
	quit $listbuild("GET /v2/web-apps", "GET /v2/web-app")
}

ClassMethod Entry(id As %String, operations As %List, privileges As %DynamicObject) As %DynamicObject
{
	set requires = [], allowed = 1, available = 1, reason = "", seen = ""
	set ptr = 0
	while $listnext(operations, ptr, operationId) {
		continue:$listfind(seen, operationId)
		set seen = seen _ $listbuild(operationId)
		set op = ##class(FlightDeck.Capability.Map).Operation(operationId)
		if '$isobject(op) {
			set available = 0
			set:reason="" reason = "Unknown operation "_operationId_"."
			continue
		}
		do requires.%Push(op.requires)
		set entry = ##class(FlightDeck.Capability.Map).Entry(op, privileges)
		if 'entry.available {
			// The version reason wins over a privilege reason (Constitution III, dialect note).
			if available set reason = entry.reason
			set available = 0
		} elseif 'entry.allowed {
			set:(reason="")&&available reason = entry.reason
			set allowed = 0
		}
	}
	set composite = {"id":(id), "requires":(requires)}
	do composite.%Set("allowed", allowed, "boolean")
	do composite.%Set("available", available, "boolean")
	do composite.%Set("reason", reason, $select(reason="":"null", 1:"string"))
	quit composite
}

/// One composite for the signed-in user, or "".
ClassMethod Current(id As %String) As %DynamicObject
{
	set iter = ..Build(##class(FlightDeck.Capability.Map).CurrentPrivileges()).%GetIterator()
	while iter.%GetNext(, .entry) { if entry.id = id return entry }
	quit ""
}

}

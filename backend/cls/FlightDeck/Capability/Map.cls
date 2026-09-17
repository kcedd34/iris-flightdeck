/// Session capability map (Constitution III, FR-013/FR-014): the privilege each official operation
/// declares (FlightDeck.Capability.Spec, generated from docs/sysadmin-api-v2.json) crossed with the
/// privileges /info reports for the signed-in user. There is no hand-written privilege table.
Class FlightDeck.Capability.Map [ Abstract ]
{

/// /info.result.privileges uses keys without the %Admin_ prefix ("Secure": {"use": true}).
/// Returns {"%Admin_Secure": {"use": true}, ...}.
ClassMethod NormalizePrivileges(infoPrivileges As %DynamicObject) As %DynamicObject
{
	set out = {}
	if '$isobject(infoPrivileges) quit out
	set iter = infoPrivileges.%GetIterator()
	while iter.%GetNext(.key, .value) {
		set name = $select($extract(key, 1, 7) = "%Admin_":key, 1:"%Admin_"_key)
		set entry = {}
		do entry.%Set("use", $select($isobject(value):''value.use, 1:0), "boolean")
		do out.%Set(name, entry)
	}
	quit out
}

/// Builds all capability entries for normalized privileges.
ClassMethod Build(privileges As %DynamicObject) As %DynamicArray
{
	set entries = []
	set iter = ##class(FlightDeck.Capability.Spec).Operations().%GetIterator()
	while iter.%GetNext(, .op) {
		do entries.%Push(..Entry(op, privileges))
	}
	quit entries
}

/// One capability entry for an operation of the generated specification data.
ClassMethod Entry(op As %DynamicObject, privileges As %DynamicObject) As %DynamicObject
{
	set allowed = ..Allowed(op.requires, privileges)
	set entry = {
		"operationId": (op.operationId), "method": (op.method), "path": (op.path),
		"domain": (op.domain), "summary": (op.summary), "requires": (op.requires)
	}
	// On the v1 dialect an operation without a v1 route is unavailable (Constitution III, dialect
	// note): the privilege still comes from the v2 declaration, and the version reason wins.
	set available = ##class(FlightDeck.Admin.Client).Has(op.operationId)
	do entry.%Set("mutating", op.mutating, "boolean")
	do entry.%Set("allowed", allowed, "boolean")
	do entry.%Set("available", available, "boolean")
	if 'available {
		do entry.%Set("reason", ##class(FlightDeck.Admin.Client).UnavailableReason(op.operationId))
	} elseif allowed {
		do entry.%Set("reason", "", "null")
	} else {
		do entry.%Set("reason", ##class(FlightDeck.API.Response).RequiresMessage(op.requires))
	}
	quit entry
}

/// The generated operation data for one operationId, or "" when the specification has none.
ClassMethod Operation(operationId As %String) As %DynamicObject
{
	if '$isobject($get(%FlightDeckOperations)) {
		set %FlightDeckOperations = {}
		set iter = ##class(FlightDeck.Capability.Spec).Operations().%GetIterator()
		while iter.%GetNext(, .op) { do %FlightDeckOperations.%Set(op.operationId, op) }
	}
	quit %FlightDeckOperations.%Get(operationId)
}

/// The signed-in user's normalized privileges from /info, cached for 5 s in the IRIS session.
ClassMethod CurrentPrivileges() As %DynamicObject
{
	set haveSession = ($data(%session)#2) && $isobject($get(%session))
	if haveSession {
		set cached = $get(%session.Data("fd.privileges"))
		if (cached '= "") && ($zhorolog - $list(cached, 1) < 5) quit ##class(%DynamicAbstractObject).%FromJSON($list(cached, 2))
	}
	set info = ##class(FlightDeck.Admin.Client).Get("/info", , .status)
	set privileges = ..NormalizePrivileges($select($isobject(info):info.privileges, 1:""))
	if haveSession set %session.Data("fd.privileges") = $listbuild($zhorolog, privileges.%ToJSON())
	quit privileges
}

/// The capability entry of one operation for the signed-in user.
ClassMethod CurrentEntry(operationId As %String) As %DynamicObject
{
	// Pattern catalog operations exist only on a fixtures install (feature 002 research R13).
	if ##class(FlightDeck.Domain.Upstream).IsFixture($piece(operationId, " ", 2)) {
		quit $classmethod(##class(FlightDeck.Domain.Fixtures).#CATALOG, "Capability", operationId)
	}
	set op = ..Operation(operationId)
	if '$isobject(op) quit {"operationId":(operationId), "allowed":false, "available":false, "reason":"Unknown operation."}
	quit ..Entry(op, ..CurrentPrivileges())
}

/// OR semantics: allowed when nothing is required, or when any listed privilege is held with Use.
/// A privilege key absent from /info counts as not held.
ClassMethod Allowed(requires As %DynamicArray, privileges As %DynamicObject) As %Boolean
{
	if '$isobject(requires) || (requires.%Size() = 0) quit 1
	set allowed = 0
	set iter = requires.%GetIterator()
	while iter.%GetNext(, .requirement) {
		set resource = $piece(requirement, ":", 1)
		set held = privileges.%Get(resource)
		if $isobject(held), held.use {
			set allowed = 1
			quit
		}
	}
	quit allowed
}

/// allowed counts operations the user may run on this instance (privilege held and available);
/// unavailable counts operations the instance's dialect does not offer.
ClassMethod Summary(entries As %DynamicArray) As %DynamicObject
{
	set allowed = 0, unavailable = 0
	set iter = entries.%GetIterator()
	while iter.%GetNext(, .entry) {
		if 'entry.available { set unavailable = unavailable + 1 continue }
		set:entry.allowed allowed = allowed + 1
	}
	quit {"allowed":(allowed), "unavailable":(unavailable), "total":(entries.%Size())}
}

/// The privileges the v2 specification declares for one operation ("" when unknown).
ClassMethod Requires(operationId As %String) As %DynamicArray
{
	set iter = ##class(FlightDeck.Capability.Spec).Operations().%GetIterator()
	while iter.%GetNext(, .op) {
		if op.operationId = operationId return op.requires
	}
	quit ""
}

/// OR semantics over the current process's roles, for native providers that fill a gap in place of
/// a declared operation: the same privilege the official operation declares is required.
ClassMethod CurrentUserMay(operationId As %String) As %Boolean
{
	set requires = ..Requires(operationId)
	if '$isobject(requires) quit 0
	if requires.%Size() = 0 quit 1
	set iter = requires.%GetIterator()
	while iter.%GetNext(, .requirement) {
		if $system.Security.Check($piece(requirement, ":", 1), "USE") return 1
	}
	quit 0
}

/// Every distinct privilege any operation declares, sorted. Used in NO_ADMIN_PRIVILEGE errors.
ClassMethod AllRequiredPrivileges() As %DynamicArray
{
	set seen = ""
	set iter = ##class(FlightDeck.Capability.Spec).Operations().%GetIterator()
	while iter.%GetNext(, .op) {
		set r = op.requires.%GetIterator()
		while r.%GetNext(, .requirement) { set seen(requirement) = "" }
	}
	set out = []
	set key = ""
	for { set key = $order(seen(key)) quit:key=""  do out.%Push(key) }
	quit out
}

}

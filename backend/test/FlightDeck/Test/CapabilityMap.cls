Class FlightDeck.Test.CapabilityMap Extends %UnitTest.TestCase
{

Method Privileges(held...) As %DynamicObject
{
	set out = {}
	for i=1:1:$get(held) {
		set entry = {}
		do entry.%Set("use", 1, "boolean")
		do out.%Set(held(i), entry)
	}
	quit out
}

Method Find(entries As %DynamicArray, operationId As %String) As %DynamicObject
{
	set found = ""
	set iter = entries.%GetIterator()
	while iter.%GetNext(, .e) { if e.operationId = operationId { set found = e quit } }
	quit found
}

Method TestCountsAndUniqueness()
{
	set entries = ##class(FlightDeck.Capability.Map).Build(..Privileges())
	do $$$AssertEquals(entries.%Size(), 273)
	set seen = "", domains = ""
	set iter = entries.%GetIterator()
	while iter.%GetNext(, .e) {
		do:$data(seen(e.operationId)) $$$AssertFailure("duplicate "_e.operationId)
		set seen(e.operationId) = ""
		set domains(e.domain) = $get(domains(e.domain)) + 1
	}
	for pair = "shell:5", "web-apps:8", "permissions:31", "security:89", "tasks:24", "system:102", "logs:14" {
		do $$$AssertEquals($get(domains($piece(pair, ":", 1))), $piece(pair, ":", 2), "domain "_pair)
	}
}

Method TestSecureRequiredForRoles()
{
	set entries = ##class(FlightDeck.Capability.Map).Build(..Privileges("%Admin_Operate"))
	set roles = ..Find(entries, "GET /v2/security/roles")
	do $$$AssertNotTrue(roles.allowed)
	do $$$AssertEquals(roles.reason, "Requires Use on %Admin_Secure. Ask your instance administrator for access.")
}

/// Any one of several declared privileges is enough. The operation is chosen from the map by
/// availability, so the test holds on every instance (no version check, Constitution III).
Method TestOrSemantics()
{
	set all = ##class(FlightDeck.Capability.Map).Build(..Privileges()), op = ""
	set iter = all.%GetIterator()
	while iter.%GetNext(, .e) { if e.available && (e.requires.%Size() > 1) { set op = e quit } }
	do $$$AssertTrue($isobject(op), "an available operation declares more than one privilege")
	quit:'$isobject(op)
	set first = $piece(op.requires.%Get(0), ":", 1), second = $piece(op.requires.%Get(1), ":", 1)
	set entry = ..Find(##class(FlightDeck.Capability.Map).Build(..Privileges(second)), op.operationId)
	do $$$AssertTrue(entry.allowed, op.operationId_" allowed with "_second_" only")
	do $$$AssertEquals(entry.reason, "")
	do $$$AssertEquals(..Find(all, op.operationId).reason, "Requires Use on "_first_" or "_second_". Ask your instance administrator for access.")
}

Method TestInfoAlwaysAllowed()
{
	set entries = ##class(FlightDeck.Capability.Map).Build(..Privileges())
	do $$$AssertTrue(..Find(entries, "GET /info").allowed)
}

Method TestReadOnlyPostsAreNotMutations()
{
	set entries = ##class(FlightDeck.Capability.Map).Build(..Privileges())
	do $$$AssertNotTrue(..Find(entries, "POST /v2/security/audit/records").mutating)
	do $$$AssertTrue(..Find(entries, "DELETE /v2/security/role").mutating)
}

Method TestNormalizePrivileges()
{
	set info = {"Secure":{"use":true}, "Operate":{"use":false}}
	set normalized = ##class(FlightDeck.Capability.Map).NormalizePrivileges(info)
	do $$$AssertTrue(normalized.%Get("%Admin_Secure").use)
	do $$$AssertNotTrue(normalized.%Get("%Admin_Operate").use)
}

}

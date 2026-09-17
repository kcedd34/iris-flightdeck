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

Method TestOrSemantics()
{
	set entries = ##class(FlightDeck.Capability.Map).Build(..Privileges("%Admin_Operate"))
	set dbs = ..Find(entries, "GET /v2/databases")
	do $$$AssertTrue(dbs.allowed, "databases allowed with Operate only")
	do $$$AssertEquals(dbs.reason, "")
	set none = ##class(FlightDeck.Capability.Map).Build(..Privileges())
	do $$$AssertEquals(..Find(none, "GET /v2/databases").reason, "Requires Use on %Admin_Manage or %Admin_Operate. Ask your instance administrator for access.")
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

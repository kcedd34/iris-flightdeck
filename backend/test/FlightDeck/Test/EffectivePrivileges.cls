/// Effective privileges with provenance (RN-FD-10, feature 003 US1 scenarios 1 and 2) and the other
/// permission link providers. The demo chain FD_Demo_L1 -> L2 -> L3 -> FD_Demo_Billing is the
/// subject, so an inherited grant must be explained by three roles, not asserted bare.
Class FlightDeck.Test.EffectivePrivileges Extends %UnitTest.TestCase
{

Parameter USER = "FDT_ChainUser";

Method OnBeforeAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("POST", "/v2/security/user", {"name":(..#USER)}, {"Password":"Fd-Test-Pass-2026", "User":{"Enabled":true, "ChangePassword":false, "FullName":"FlightDeck test", "Roles":["FD_Demo_L1", "FD_Demo_Operator"]}}, .status)
	quit $$$OK
}

Method OnAfterAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/user", {"name":(..#USER)}, , .status)
	quit $$$OK
}

Method OnBeforeOneTest(testname As %String) As %Status
{
	kill %FlightDeckRoleDetail, %FlightDeckRoleOwners
	quit $$$OK
}

ClassMethod Entity(entityType As %String, name As %String) As %DynamicObject
{
	set type = ##class(FlightDeck.Domain.Descriptor).EntityType("permissions", entityType)
	quit ##class(FlightDeck.Domain.Entity).Read(type, {"name":(name)}, .status)
}

/// An inherited privilege appears, and the chain that grants it appears with it.
Method TestInheritedPrivilegeCarriesItsChain()
{
	set group = ##class(FlightDeck.Domain.Links.EffectivePrivileges).Group(..Entity("user", ..#USER))
	do $$$AssertEquals(group.state, "ok")
	set found = ""
	set iter = group.items.%GetIterator()
	while iter.%GetNext(, .item) { if item.displayName = "FD_Demo_Billing:U" set found = item }
	do $$$AssertTrue($isobject(found), "the inherited privilege is listed")
	quit:'$isobject(found)
	do $$$AssertTrue(found.detail [ "FD_Demo_L1", "the chain names the role the user holds")
	do $$$AssertTrue(found.detail [ "FD_Demo_L3", "the chain names the role that grants the resource")
}

/// Every item carries an origin: a privilege without one is never emitted.
Method TestNoPrivilegeWithoutOrigin()
{
	set group = ##class(FlightDeck.Domain.Links.EffectivePrivileges).Group(..Entity("user", ..#USER))
	set iter = group.items.%GetIterator()
	while iter.%GetNext(, .item) {
		do $$$AssertTrue($extract(item.detail, 1, 4) = "via ", item.displayName_" states its origin")
	}
	do $$$AssertTrue(group.items.%Size() >= 2, "the direct and the inherited grant are both listed")
}

/// The same provider answers for a role, seeded by the role itself.
Method TestRoleSeedsItself()
{
	set group = ##class(FlightDeck.Domain.Links.EffectivePrivileges).Group(..Entity("role", "FD_Demo_L1"))
	set found = 0
	set iter = group.items.%GetIterator()
	while iter.%GetNext(, .item) { if item.displayName = "FD_Demo_Billing:U" set found = 1 }
	do $$$AssertTrue(found, "a role's own inherited grant is listed")
}

/// Direct and inherited roles are distinguished, and the chain excludes the role itself.
Method TestUserRolesDistinguishDirectFromInherited()
{
	set group = ##class(FlightDeck.Domain.Links.UserRoles).Group(..Entity("user", ..#USER))
	kill byName
	set iter = group.items.%GetIterator()
	while iter.%GetNext(, .item) { set byName(item.displayName) = item.detail }
	do $$$AssertEquals($get(byName("FD_Demo_L1")), "direct")
	do $$$AssertEquals($get(byName("FD_Demo_L2")), "through FD_Demo_L1")
	do $$$AssertEquals($get(byName("FD_Demo_L3")), "through FD_Demo_L1, FD_Demo_L2")
}

/// What a resource protects comes from official listings, and a refused source is named.
Method TestResourceObjectsListsWhatItProtects()
{
	set group = ##class(FlightDeck.Domain.Links.ResourceObjects).Group(..Entity("resource", "FD_Demo_Reports"))
	set names = ""
	set iter = group.items.%GetIterator()
	while iter.%GetNext(, .item) { set names = names _ " " _ item.displayName }
	do $$$AssertTrue(names [ "/csp/fd-demo-reports", "the demo web application is protected by it")
	do $$$AssertTrue(names [ "FD_Demo_Vault", "the demo wallet collection is protected by it")
}

/// The SQL panel declares its parameter and answers only once it has one (probe P4).
Method TestSqlPrivilegesNeedsANamespaceAndUsesTheApiProvenance()
{
	set entity = ..Entity("user", ..#USER)
	set waiting = ##class(FlightDeck.Domain.Links.SqlPrivileges).Group(entity)
	do $$$AssertEquals(waiting.state, "needs-parameter")
	do $$$AssertEquals(waiting.parameters.%Get(0).name, "namespace")
	set answered = ##class(FlightDeck.Domain.Links.SqlPrivileges).Group(entity, {"namespace":($namespace)})
	do $$$AssertEquals(answered.state, "ok")
	do $$$AssertEquals(answered.parameters.%Get(0).value, $namespace, "the answer states the value it used")
	set iter = answered.items.%GetIterator()
	while iter.%GetNext(, .item) {
		do $$$AssertTrue(item.detail '= "", item.displayName_" carries the provenance the API reports")
	}
}

}

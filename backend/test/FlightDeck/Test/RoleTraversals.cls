/// The two role traversals (feature 003 T015 and T016), on the demo chain
/// FD_Demo_L1 -> FD_Demo_L2 -> FD_Demo_L3 -> FD_Demo_Billing.
/// <p>Probe P2 showed GrantedRoles is one level deep, and probe finding B showed role/owners
/// answers with direct owners that may be roles. Both are asserted here so a platform change that
/// silently deepens or flattens either answer fails a test instead of a screen.
Class FlightDeck.Test.RoleTraversals Extends %UnitTest.TestCase
{

Parameter HOLDER = "FDT_ChainHolder";

Method OnBeforeAllTests() As %Status
{
	// A user that holds the top of the demo chain, so the inverse traversal has three levels to walk.
	do ##class(FlightDeck.Admin.Client).Call("POST", "/v2/security/user", {"name":(..#HOLDER)}, {"Password":"Fd-Test-Pass-2026", "User":{"Enabled":true, "ChangePassword":false, "FullName":"FlightDeck test", "Roles":["FD_Demo_L1"]}}, .status)
	kill %FlightDeckRoleDetail, %FlightDeckRoleOwners
	quit $$$OK
}

Method OnAfterAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/user", {"name":(..#HOLDER)}, , .status)
	quit $$$OK
}

Method OnBeforeOneTest(testname As %String) As %Status
{
	kill %FlightDeckRoleDetail, %FlightDeckRoleOwners
	quit $$$OK
}

/// Forward: from the top role to the resource three levels below, with the chain.
Method TestForwardTraversalKeepsTheChain()
{
	set answer = ##class(FlightDeck.Domain.Links.RoleGraph).Expand([{"role":"FD_Demo_L1", "kind":"role"}])
	do $$$AssertNotTrue(answer.truncated, "the demo chain fits the caps")
	set found = ""
	set iter = answer.roles.%GetIterator()
	while iter.%GetNext(, .entry) { if entry.role = "FD_Demo_L3" set found = entry }
	do $$$AssertTrue($isobject(found), "the deepest role is reached")
	quit:'$isobject(found)
	do $$$AssertEquals(found.path.%Size(), 3, "the chain has three steps")
	do $$$AssertEquals(found.path.%Get(0), "FD_Demo_L1")
	do $$$AssertEquals(found.path.%Get(2), "FD_Demo_L3")
	do $$$AssertEquals(found.resources.%Get(0).Name, "FD_Demo_Billing", "the resource is on the deepest role only")
}

/// The API answers one level at a time: the middle role's own detail names only the next one.
Method TestGrantedRolesIsOneLevelDeep()
{
	set detail = ##class(FlightDeck.Domain.Links.RoleGraph).Detail("FD_Demo_L1", .status)
	do $$$AssertEquals(status, 200)
	do $$$AssertEquals(detail.GrantedRoles.%Size(), 1)
	do $$$AssertEquals(detail.GrantedRoles.%Get(0), "FD_Demo_L2")
	do $$$AssertEquals(detail.Resources.%Size(), 0, "no resource on the top role")
}

/// Inverse: the user three levels above is found, although role/owners reports roles as owners.
Method TestInverseTraversalFindsTheUserThreeLevelsUp()
{
	set direct = ##class(FlightDeck.Domain.Links.RoleHolders).Owners("FD_Demo_L3", .status)
	do $$$AssertEquals(status, 200)
	do $$$AssertEquals(direct.%Get(0).Type, "Role", "the direct owner of the deepest role is a role")
	set answer = ##class(FlightDeck.Domain.Links.RoleHolders).Users("FD_Demo_L3")
	do $$$AssertNotTrue(answer.truncated)
	set found = 0
	set iter = answer.users.%GetIterator()
	while iter.%GetNext(, .user) { if user.name = ..#HOLDER set found = 1 }
	do $$$AssertTrue(found, "the user holding the top role is found from the deepest role")
}

/// A cycle terminates instead of walking forever.
Method TestCycleTerminates()
{
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/security/role", {"name":"FDT_CycleA"}, {"Description":"cycle a"}, .status)
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/security/role", {"name":"FDT_CycleB"}, {"Description":"cycle b", "GrantedRoles":["FDT_CycleA"]}, .status)
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/security/role", {"name":"FDT_CycleA"}, {"Description":"cycle a", "GrantedRoles":["FDT_CycleB"]}, .status)
	kill %FlightDeckRoleDetail
	set answer = ##class(FlightDeck.Domain.Links.RoleGraph).Expand([{"role":"FDT_CycleA", "kind":"role"}])
	do $$$AssertEquals(answer.roles.%Size(), 2, "each role in the cycle is visited once")
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/role", {"name":"FDT_CycleA"}, , .status)
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/role", {"name":"FDT_CycleB"}, , .status)
}

}

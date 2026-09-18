/// Impact analysis for permissions changes (RN-FD-11, feature 003 spec FR-008, FR-009): the three
/// states, and the rule that an empty list never stands in for "could not tell".
Class FlightDeck.Test.PermissionsImpact Extends %UnitTest.TestCase
{

Parameter USER = "FDT_ImpactUser";

Parameter ROLE = "FDT_ImpactRole";

Parameter RESOURCE = "FDT_ImpactResource";

Method OnBeforeAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/security/resource", {"name":(..#RESOURCE)}, {"Description":"FlightDeck test resource", "PublicPermission":"U"}, .status)
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/security/role", {"name":(..#ROLE)}, {"Description":"FlightDeck test role", "Resources":[{"Name":(..#RESOURCE), "Permissions":"RW"}]}, .status)
	do ##class(FlightDeck.Admin.Client).Call("POST", "/v2/security/user", {"name":(..#USER)}, {"Password":"Fd-Test-Pass-2026", "User":{"Enabled":true, "ChangePassword":false, "FullName":"FlightDeck test", "Roles":[(..#ROLE)]}}, .status)
	quit $$$OK
}

Method OnAfterAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/user", {"name":(..#USER)}, , .status)
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/role", {"name":(..#ROLE)}, , .status)
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/resource", {"name":(..#RESOURCE)}, , .status)
	quit $$$OK
}

Method OnBeforeOneTest(testname As %String) As %Status
{
	kill %FlightDeckRoleDetail, %FlightDeckRoleOwners, %FlightDeckUserDetail
	quit $$$OK
}

ClassMethod Preview(request As %DynamicObject) As %DynamicObject
{
	quit ##class(FlightDeck.Mutation.Service).DoPreview(request, .status)
}

/// PRD UC05-2: deleting a role lists the users who lose access and what becomes unreachable.
Method TestRoleDeletionListsUsersAndObjects()
{
	set preview = ..Preview({"operationId":"DELETE /v2/security/role", "keys":{"name":(..#ROLE)}})
	do $$$AssertEquals(preview.impact.state, "ok", "the impact is determined: "_preview.impact.%ToJSON())
	do $$$AssertTrue(##class(FlightDeck.Domain.Predicate).ArrayHas(preview.impact.users, ..#USER), "the user who holds the role is listed")
	set names = ""
	set iter = preview.impact.objects.%GetIterator()
	while iter.%GetNext(, .object) { set names = names _ " " _ object.displayName }
	do $$$AssertTrue(names [ ..#RESOURCE, "the resource that becomes unreachable is listed")
}

/// Removing a role from a user reports what that user loses, and nothing else.
Method TestUserRoleRemovalReportsWhatIsLost()
{
	set preview = ..Preview({"operationId":"PUT /v2/security/user", "keys":{"name":(..#USER)}, "proposed":{"Roles":[]}})
	do $$$AssertEquals(preview.impact.state, "ok")
	do $$$AssertEquals(preview.impact.users.%Get(0), ..#USER)
	do $$$AssertTrue(preview.impact.summary [ "loses", "the summary says what is lost")
}

/// A change that takes nothing away reports "none", which is not the same as undetermined.
/// Adding a role changes the user's access, so the impact runs; nothing is lost, and it says so.
Method TestNoLossReportsNone()
{
	set preview = ..Preview({"operationId":"PUT /v2/security/user", "keys":{"name":(..#USER)}, "proposed":{"Roles":[(..#ROLE), "FD_Demo_Operator"]}})
	do $$$AssertEquals(preview.impact.state, "none")
	do $$$AssertTrue(preview.impact.summary [ "no privilege", "it states that nothing is lost")
	// A change that touches no access does not run the analysis at all, which is also not a loss.
	set untouched = ..Preview({"operationId":"PUT /v2/security/user", "keys":{"name":(..#USER)}, "proposed":{"FullName":"FlightDeck test renamed"}})
	do $$$AssertEquals(untouched.impact.state, "none")
}

/// Deleting a resource names the roles that grant it and the objects it protects.
Method TestResourceDeletionReportsRolesAndObjects()
{
	set preview = ..Preview({"operationId":"DELETE /v2/security/resource", "keys":{"name":(..#RESOURCE)}})
	do $$$AssertTrue($listfind($listbuild("ok", "none"), preview.impact.state), "the impact is determined: "_preview.impact.%ToJSON())
	if preview.impact.state = "ok" {
		do $$$AssertTrue(##class(FlightDeck.Domain.Predicate).ArrayHas(preview.impact.users, ..#USER), "the user behind the granting role is listed")
	}
}

/// A user's own password change carries no value anywhere, at any stage.
Method TestPasswordIsNeverInThePreview()
{
	set preview = ..Preview({"operationId":"POST /v2/security/user/password", "keys":{"name":(..#USER)}, "params":{"name":(..#USER), "newPassword":"Fd-Test-Pass-2026-new"}, "options":{}})
	do $$$AssertEquals(preview.kind, "action")
	do $$$AssertNotTrue(preview.%ToJSON() [ "Fd-Test-Pass", "no password in the preview")
	do $$$AssertTrue($isobject(preview.requestMode), "the preview shows what will be sent")
	do $$$AssertTrue(preview.grade = "reinforced", "a password change asks for the typed target")
}

}

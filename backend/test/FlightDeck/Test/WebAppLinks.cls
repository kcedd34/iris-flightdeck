/// Link providers for web applications (feature 002 T023, research R6).
Class FlightDeck.Test.WebAppLinks Extends %UnitTest.TestCase
{

Method Entity(name As %String) As %DynamicObject
{
	set type = ##class(FlightDeck.Domain.Descriptor).EntityType("web-apps", "web-application")
	quit ##class(FlightDeck.Domain.Entity).Read(type, {"name":(name)}, .status)
}

Method OnBeforeOneTest(testname As %String) As %Status
{
	do ##class(FlightDeck.Domain.LinkCache).Invalidate()
	quit $$$OK
}

Method TestResourceRolesDirectInheritedAndAll()
{
	set roles = ##class(FlightDeck.Domain.Links.ResourceRoles).Granting("FD_Demo_Reports", .failure)
	do $$$AssertNotTrue($isobject(failure))
	set found = ""
	set iter = roles.%GetIterator()
	while iter.%GetNext(, .grant) { set found(grant.role) = grant.detail }
	do $$$AssertEquals($get(found("FD_Demo_Operator")), "RW")
	do $$$AssertEquals($get(found("FD_Demo_Auditor")), "R")
	do $$$AssertEquals($get(found("%All")), "all resources")
	set dev = ##class(FlightDeck.Domain.Links.ResourceRoles).Granting("%Development", .failure)
	set inherited = 0
	set iter = dev.%GetIterator()
	while iter.%GetNext(, .grant) { set:grant.detail[" through " inherited = 1 }
	do $$$AssertTrue(inherited, "a role granted through another role is reported with its path")
}

Method TestOwnersMatchOfficialRoleOwners()
{
	set users = ##class(FlightDeck.Domain.Links.RoleOwners).Users("%Development", .failure)
	do $$$AssertNotTrue($isobject(failure))
	set owners = ##class(FlightDeck.Admin.Client).Get("/v2/security/role/owners", {"name":"%All", "maxRows":1000})
	set iter = owners.%GetIterator()
	while iter.%GetNext(, .owner) {
		continue:owner.Type'["User"
		do $$$AssertTrue(users.%IsDefined(owner.Name), "owner of %All listed: "_owner.Name)
	}
	set detail = users.%Get("_SYSTEM")
	do $$$AssertEquals($length(detail, "%All"), 2, "a role is listed once per user: "_detail)
}

Method TestProtectedDemoApplicationGroups()
{
	set type = ##class(FlightDeck.Domain.Descriptor).EntityType("web-apps", "web-application")
	set entity = ..Entity("/csp/fd-demo-reports")
	do $$$AssertTrue($isobject(entity), "demo application /csp/fd-demo-reports exists")
	quit:'$isobject(entity)
	set groups = ##class(FlightDeck.API.Entities).Groups(type, entity)
	set byProvider = {}
	set iter = groups.%GetIterator()
	while iter.%GetNext(, .g) { do byProvider.%Set(g.provider, g) }
	do $$$AssertEquals(byProvider."resource-roles".state, "ok")
	do $$$AssertTrue(byProvider."resource-roles".count >= 3)
	do $$$AssertTrue(byProvider."resource-public".label [ "Every user holds U", byProvider."resource-public".label)
	do $$$AssertEquals(byProvider."role-owners".state, "ok")
}

Method TestNoResourceAndForbidden()
{
	set type = ##class(FlightDeck.Domain.Descriptor).EntityType("web-apps", "web-application")
	set groups = ##class(FlightDeck.API.Entities).Groups(type, ..Entity("/csp/fd-demo"))
	do $$$AssertEquals(groups.%Get(0).label, "Not restricted by a resource")
	set group = ##class(FlightDeck.Domain.LinkProviders).FromFailure(##class(FlightDeck.Domain.LinkProviders).NewGroup("resource-roles", "x"), "GET /v2/security/roles", 403, "", "")
	do $$$AssertEquals(group.state, "forbidden")
	do $$$AssertEquals(group.reason, ##class(FlightDeck.API.Response).RequiresMessage(["%Admin_Secure:U"]))
}

}

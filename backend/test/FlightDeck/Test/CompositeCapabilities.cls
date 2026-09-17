/// Composite capabilities (feature 002 T013): AND across the official operations a feature calls,
/// derived from descriptors and the generated capability data.
Class FlightDeck.Test.CompositeCapabilities Extends %UnitTest.TestCase
{

Method TestAllowedOnlyWithEveryDeclaredPrivilege()
{
	set ops = $listbuild("GET /v2/web-app", "GET /v2/security/roles")
	set secure = {"%Admin_Secure":{"use":true}}
	set allowed = ##class(FlightDeck.Capability.Composite).Entry("probe", ops, secure)
	do $$$AssertTrue(allowed.allowed)
	do $$$AssertEquals(allowed.requires.%Size(), 2)
	set operator = {"%Admin_Operate":{"use":true}}
	set refused = ##class(FlightDeck.Capability.Composite).Entry("probe", ops, operator)
	do $$$AssertNotTrue(refused.allowed)
	do $$$AssertEquals(refused.reason, ##class(FlightDeck.API.Response).RequiresMessage(["%Admin_Secure:U"]))
}

Method TestUnavailableOperationMakesCompositeUnavailable()
{
	set entry = ##class(FlightDeck.Capability.Composite).Entry("probe", $listbuild("GET /v2/web-app", "GET /v2/fdt-nope"), {"%Admin_Secure":{"use":true}})
	do $$$AssertNotTrue(entry.available)
	do $$$AssertTrue(entry.reason [ "Unknown operation", entry.reason)
}

Method TestBuildCoversEveryEntityType()
{
	set ids = ""
	set iter = ##class(FlightDeck.Capability.Composite).Build({}).%GetIterator()
	while iter.%GetNext(, .entry) { set ids(entry.id) = "" }
	for id = "web-apps/web-application.list", "web-apps/web-application.links", "web-apps/pct-access.detail", "permissions/role.detail", "rest.execute" {
		do $$$AssertTrue($data(ids(id)), id)
	}
}

}

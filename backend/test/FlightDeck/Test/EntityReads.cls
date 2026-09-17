/// Generic descriptor-driven reads (feature 002 T012): official objects unchanged, failures passed
/// through, list capped, no version check (runs on both dialects).
Class FlightDeck.Test.EntityReads Extends %UnitTest.TestCase
{

Method Type(id As %String) As %DynamicObject
{
	quit ##class(FlightDeck.Domain.Descriptor).EntityType($piece(id, "/", 1), $piece(id, "/", 2))
}

Method TestListItemsAreOfficialObjectsUnchanged()
{
	set type = ..Type("web-apps/web-application")
	set items = ##class(FlightDeck.Domain.Entity).List(type, {"maxRows":1000}, .status)
	do $$$AssertEquals(status, 200)
	set official = ##class(FlightDeck.Admin.Client).Get("/v2/web-apps", {"maxRows":1000})
	do $$$AssertEquals(items.%ToJSON(), official.%ToJSON(), "list forwarded unchanged")
}

Method TestDetailIsOfficialObjectUnchanged()
{
	set type = ..Type("web-apps/web-application")
	set entity = ##class(FlightDeck.Domain.Entity).Read(type, {"name":"/csp/fd-demo"}, .status)
	do $$$AssertEquals(status, 200)
	set official = ##class(FlightDeck.Admin.Client).Get("/v2/web-app", {"name":"/csp/fd-demo"})
	do $$$AssertEquals(entity.object.%ToJSON(), official.%ToJSON())
	do $$$AssertEquals(entity.displayName, "/csp/fd-demo")
}

Method TestNotFoundPassesThrough()
{
	set type = ..Type("web-apps/web-application")
	set entity = ##class(FlightDeck.Domain.Entity).Read(type, {"name":"/csp/fdt-does-not-exist"}, .status, .json, .raw)
	do $$$AssertNotTrue($isobject(entity))
	do $$$AssertEquals(status, 404)
	do $$$AssertTrue(##class(FlightDeck.Admin.Client).ErrorText(json, raw) [ "does not exist", raw)
}

Method TestCappedAtMaxRows()
{
	set type = ..Type("web-apps/web-application")
	set items = ##class(FlightDeck.Domain.Entity).List(type, {"maxRows":2}, .status)
	do $$$AssertEquals(items.%Size(), 2, "the official maxRows is honored, so a full page means capped")
}

Method TestPctAccessKeysAndDisplayName()
{
	set type = ..Type("web-apps/pct-access")
	set items = ##class(FlightDeck.Domain.Entity).List(type, {"maxRows":5}, .status)
	do $$$AssertEquals(status, 200)
	set item = items.%Get(0)
	set keys = ##class(FlightDeck.Domain.Entity).KeysFromItem(type, item)
	do $$$AssertEquals(keys.name, item.Name)
	do $$$AssertEquals(##class(FlightDeck.Domain.Entity).DisplayName(type, keys), item.Class_" ("_item.AllowType_") on "_item.Name)
	set entity = ##class(FlightDeck.Domain.Entity).Read(type, keys, .status)
	do $$$AssertEquals(status, 200)
	do $$$AssertEquals(entity.object.AllowAccess, item.AllowAccess)
}

}

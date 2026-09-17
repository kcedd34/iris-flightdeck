/// Graded exposure markers in the web applications list (feature 002 T022, research R10,
/// verification/flightdeck-web-apps-exposure-2026.2.md).
Class FlightDeck.Test.WebAppExposure Extends %UnitTest.TestCase
{

Method Markers(item As %DynamicObject) As %String
{
	set type = ##class(FlightDeck.Domain.Descriptor).EntityType("web-apps", "web-application")
	set facts = ##class(FlightDeck.Domain.Facts).For(type.facts, item)
	set markers = ##class(FlightDeck.Domain.Entity).Markers(type, item, facts)
	set ids = ""
	set iter = markers.%GetIterator()
	while iter.%GetNext(, .m) { set ids = ids _ $select(ids="":"", 1:",") _ m.id }
	quit ids
}

Method ListItem(name As %String) As %DynamicObject
{
	set list = ##class(FlightDeck.Admin.Client).Get("/v2/web-apps", {"filter":(name), "maxRows":100})
	set iter = list.%GetIterator()
	while iter.%GetNext(, .item) { if item.Name = name return item }
	quit ""
}

Method TestInstalledApplications()
{
	do $$$AssertEquals(..Markers(..ListItem("/api/monitor")), "open-api", "unauthenticated REST API")
	do $$$AssertEquals(..Markers(..ListItem("/csp/fd-demo")), "no-auth", "unauthenticated, no dispatcher")
	do $$$AssertTrue(..Markers(..ListItem("/flightdeck")) [ "static-only", "verified static files")
	do $$$AssertNotTrue(..Markers(..ListItem("/flightdeck")) [ "open-api")
	do $$$AssertNotTrue(..Markers(..ListItem("/flightdeck")) [ "no-auth")
	set api = ..Markers(..ListItem("/api/flightdeck"))
	do $$$AssertNotTrue((api [ "open-api") || (api [ "no-auth") || (api [ "static-only"), "Password only: no exposure marker ("_api_")")
}

Method TestStaticDeclarationRequiresReadOnlyRoutes()
{
	do $$$AssertTrue(##class(FlightDeck.Domain.Facts).StaticFilesDispatcher("FlightDeck.UI.Static", "USER"))
	do $$$AssertNotTrue(##class(FlightDeck.Domain.Facts).StaticFilesDispatcher("FlightDeck.Test.Probe.StaticWithPost", "USER"), "declares static files but routes POST")
	do $$$AssertNotTrue(##class(FlightDeck.Domain.Facts).StaticFilesDispatcher("FlightDeck.API.Router", "USER"), "no declaration")
}

/// The same name with a different dispatcher gets a different marker: the decision reads facts about
/// the dispatcher, not the application's name.
Method TestMarkerIgnoresName()
{
	set item = ..ListItem("/flightdeck")
	set forged = ##class(%DynamicAbstractObject).%FromJSON(item.%ToJSON())
	set forged.DispatchClass = "FlightDeck.Test.Probe.StaticWithPost"
	do $$$AssertTrue(..Markers(forged) [ "open-api", "same name, dispatcher routes POST")
}

}

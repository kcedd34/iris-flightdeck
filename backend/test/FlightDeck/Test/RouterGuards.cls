Class FlightDeck.Test.RouterGuards Extends %UnitTest.TestCase
{

Method TestUrlMapMatchesOpenApi()
{
	set routes = ""
	set xdata = ##class(%Dictionary.CompiledXData).%OpenId("FlightDeck.API.Router||UrlMap")
	while 'xdata.Data.AtEnd {
		set line = xdata.Data.ReadLine()
		if line [ "<Route " {
			set url = $piece($piece(line, "Url=""", 2), """", 1)
			set method = $piece($piece(line, "Method=""", 2), """", 1)
			// strip the /v1 prefix: the OpenAPI server URL is /api/flightdeck/v1
			set url = $extract(url, 4, *)
			// UrlMap ":name" segments are OpenAPI "{name}" path parameters
			for i=1:1:$length(url, "/") { set segment = $piece(url, "/", i) if $extract(segment) = ":" set $piece(url, "/", i) = "{"_$extract(segment, 2, *)_"}" }
			set routes(method _ " " _ url) = ""
		}
	}
	set spec = ##class(FlightDeck.API.OpenAPI).Document()
	set specOps = ""
	set paths = spec.paths.%GetIterator()
	while paths.%GetNext(.path, .item) {
		set methods = item.%GetIterator()
		while methods.%GetNext(.method) {
			set specOps($zconvert(method, "U") _ " " _ path) = ""
		}
	}
	// Two empty sets compare equal and assert nothing, so both are counted first.
	set routeCount = 0, key = ""
	for { set key = $order(routes(key)) quit:key=""  set routeCount = routeCount + 1 }
	set specCount = 0, key = ""
	for { set key = $order(specOps(key)) quit:key=""  set specCount = specCount + 1 }
	do $$$AssertTrue(routeCount > 0, "the router declares routes")
	do $$$AssertTrue(specCount > 0, "the served document declares operations")
	set key = ""
	for {
		set key = $order(routes(key))
		quit:key=""
		do $$$AssertTrue($data(specOps(key)), "route in OpenAPI: "_key)
	}
	for {
		set key = $order(specOps(key))
		quit:key=""
		do $$$AssertTrue($data(routes(key)), "OpenAPI operation routed: "_key)
	}
}

Method TestMutationsNeedDisarmedHeader()
{
	for method = "POST", "PUT", "PATCH", "DELETE" {
		for safe = "armed", "", "bogus", "DISARMED" {
			do $$$AssertEquals(##class(FlightDeck.API.Router).GuardDecision(method, "/v1/vitals", "tab", safe), "SAFE_MODE_ON", method_" with '"_safe_"'")
		}
		do $$$AssertEquals(##class(FlightDeck.API.Router).GuardDecision(method, "/v1/vitals", "tab", "disarmed"), "OK")
	}
}

Method TestUnknownRouteIsStillGuarded()
{
	do $$$AssertEquals(##class(FlightDeck.API.Router).GuardDecision("PATCH", "/v1/nothing", "tab", "armed"), "SAFE_MODE_ON")
}

Method TestSessionSignInAndOutAllowedWhileArmed()
{
	do $$$AssertEquals(##class(FlightDeck.API.Router).GuardDecision("POST", "/v1/session", "tab", "armed"), "OK")
	do $$$AssertEquals(##class(FlightDeck.API.Router).GuardDecision("DELETE", "/v1/session/", "tab", "armed"), "OK")
	do $$$AssertEquals(##class(FlightDeck.API.Router).GuardDecision("PUT", "/v1/session", "tab", "armed"), "SAFE_MODE_ON")
}

Method TestTabHeaderRequired()
{
	do $$$AssertEquals(##class(FlightDeck.API.Router).GuardDecision("GET", "/v1/vitals", "", "armed"), "MISSING_TAB_ID")
	do $$$AssertEquals(##class(FlightDeck.API.Router).GuardDecision("GET", "/v1/openapi.json", "", ""), "OK")
	do $$$AssertEquals(##class(FlightDeck.API.Router).GuardDecision("GET", "/v1/vitals", "tab", "armed"), "OK")
}

/// Feature 002: preview changes nothing and is allowed armed; apply is a mutation; execute applies
/// the guard to the method under test itself (research R3, R8).
Method TestMutationServiceRoutes()
{
	set R = "FlightDeck.API.Router"
	do $$$AssertEquals($classmethod(R, "GuardDecision", "POST", "/v1/mutations/preview", "t", "armed"), "OK")
	do $$$AssertEquals($classmethod(R, "GuardDecision", "POST", "/v1/mutations/apply", "t", "armed"), "SAFE_MODE_ON")
	do $$$AssertEquals($classmethod(R, "GuardDecision", "POST", "/v1/mutations/apply", "t", "disarmed"), "OK")
	do $$$AssertEquals($classmethod(R, "GuardDecision", "POST", "/v1/rest/execute", "t", "armed"), "OK")
	do $$$AssertEquals($classmethod(R, "GuardDecision", "GET", "/v1/domains/web-apps/web-application", "t", "armed"), "OK")
	do $$$AssertEquals($classmethod(R, "GuardDecision", "GET", "/v1/domains/web-apps/web-application", "", "armed"), "MISSING_TAB_ID")
}

/// Feature 003: an account the instance will not describe is refused for the account, not for the
/// version. The message must not send an administrator to investigate the instance.
Method TestSignInRefusalNamesTheAccountNotTheVersion()
{
	set message = ##class(FlightDeck.API.Response).#MSGNOINFO
	do $$$AssertTrue(message [ "present and answering", "it states that the API works")
	do $$$AssertTrue(message [ "about the account", "it points at the account")
	do $$$AssertNotTrue(message [ "Requires IRIS", "it is not the version message")
	do $$$AssertNotTrue(message = ##class(FlightDeck.API.Response).#MSGNOAPI, "it is not the no-API message")
}

}

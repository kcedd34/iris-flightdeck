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
			set routes(method _ " " _ $extract(url, 4, *)) = ""
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

}

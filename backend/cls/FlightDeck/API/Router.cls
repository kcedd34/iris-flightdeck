/// FlightDeck REST API, web application /api/flightdeck (contracts/flightdeck-api.openapi.json).
/// <p>Authentication is IRIS Password authentication with an IRIS-owned CSP session (research R4).
/// FlightDeck stores no credential.
/// <p>Every request passes <method>GuardDecision</method> before routing (research R5, FR-015a): a
/// missing tab id is rejected, and any mutating method from a tab whose safe mode is not
/// explicitly disarmed is rejected before a handler, or the official API, is reached.
Class FlightDeck.API.Router Extends %CSP.REST
{

Parameter UseSession = 1;

Parameter HandleCorsRequest = 0;

Parameter CHARSET = "utf-8";

Parameter CONTENTTYPE = "application/json";

/// Mutating requests that change no IRIS state and are allowed while safe mode is armed.
/// POST /v1/mutations/preview changes nothing (feature 002 research R3). POST /v1/rest/execute
/// applies the guard itself to the method of the request under test (research R8).
Parameter SAFEMODEALLOWLIST = "POST /v1/session,DELETE /v1/session,POST /v1/mutations/preview,POST /v1/rest/execute";

/// Requests allowed without the X-FlightDeck-Tab header.
Parameter TABOPTIONAL = "GET /v1/openapi.json";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/v1/session" Method="POST" Call="FlightDeck.API.Session:Create"/>
<Route Url="/v1/session" Method="GET" Call="FlightDeck.API.Session:Read"/>
<Route Url="/v1/session" Method="DELETE" Call="FlightDeck.API.Session:Delete"/>
<Route Url="/v1/session/capabilities" Method="GET" Call="FlightDeck.API.Capabilities:List"/>
<Route Url="/v1/vitals" Method="GET" Call="FlightDeck.API.Vitals:Get"/>
<Route Url="/v1/palette/entities" Method="GET" Call="FlightDeck.API.Palette:Search"/>
<Route Url="/v1/openapi.json" Method="GET" Call="FlightDeck.API.OpenAPI:Get"/>
<Route Url="/v1/domains/:domain/:entityType" Method="GET" Call="FlightDeck.API.Entities:List"/>
<Route Url="/v1/domains/:domain/:entityType/item" Method="GET" Call="FlightDeck.API.Entities:Item"/>
<Route Url="/v1/domains/:domain/:entityType/links" Method="GET" Call="FlightDeck.API.Entities:Links"/>
<Route Url="/v1/mutations/preview" Method="POST" Call="FlightDeck.API.Mutations:Preview"/>
<Route Url="/v1/mutations/apply" Method="POST" Call="FlightDeck.API.Mutations:Apply"/>
<Route Url="/v1/rest/services" Method="GET" Call="FlightDeck.API.Rest:Services"/>
<Route Url="/v1/rest/services/specification" Method="GET" Call="FlightDeck.API.Rest:Specification"/>
<Route Url="/v1/rest/execute" Method="POST" Call="FlightDeck.API.Rest:Execute"/>
</Routes>
}

/// Runs before %CSP.REST resolves any route: in %CSP.REST.DispatchRequest (IRIS 2026.2),
/// OnPreDispatch is called before DispatchMap. An unknown path or method therefore gets the same
/// safe-mode answer as a known one.
ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
	set pContinue = 1
	set decision = ..GuardDecision(pMethod, pUrl, %request.GetCgiEnv("HTTP_X_FLIGHTDECK_TAB"), %request.GetCgiEnv("HTTP_X_FLIGHTDECK_SAFE_MODE"))
	if decision = "OK" quit $$$OK
	set pContinue = 0
	if decision = "MISSING_TAB_ID" {
		quit ##class(FlightDeck.API.Response).WriteError(400, "MISSING_TAB_ID", "Missing X-FlightDeck-Tab header.")
	}
	quit ##class(FlightDeck.API.Response).WriteError(403, "SAFE_MODE_ON", ##class(FlightDeck.API.Response).#MSGSAFEMODE)
}

/// Returns "OK", "MISSING_TAB_ID" or "SAFE_MODE_ON". Pure function, unit tested in
/// FlightDeck.Test.RouterGuards.
ClassMethod GuardDecision(method As %String, path As %String, tabHeader As %String, safeModeHeader As %String) As %String
{
	set method = $zconvert(method, "U")
	set path = "/" _ $zstrip($piece(path, "?", 1), "<>", "/")
	set request = method _ " " _ path
	if $zstrip(tabHeader, "<>W") = "", '$listfind($listfromstring(..#TABOPTIONAL), request) {
		quit "MISSING_TAB_ID"
	}
	set mutating = ''$listfind($listbuild("POST", "PUT", "PATCH", "DELETE"), method)
	set allowed = ''$listfind($listfromstring(..#SAFEMODEALLOWLIST), request)
	if mutating && 'allowed && (safeModeHeader '= "disarmed") {
		quit "SAFE_MODE_ON"
	}
	quit "OK"
}

/// Published specification convention (feature 002 research R9): REST discovery reports a service
/// whose dispatch class implements this method as having a specification. FlightDeck's own API
/// publishes the OpenAPI document it serves.
ClassMethod PublishedSpecification() As %DynamicObject
{
	quit ##class(FlightDeck.API.OpenAPI).Document()
}

/// Errors thrown by handlers keep the envelope; the IRIS text is passed through verbatim.
ClassMethod Http500(ex As %Exception.AbstractException) As %Status
{
	quit ##class(FlightDeck.API.Response).WriteError(500, "UPSTREAM_ERROR", "The server could not complete the request.", ex.DisplayString())
}

}

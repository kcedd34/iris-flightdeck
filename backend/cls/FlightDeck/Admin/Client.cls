/// The only way FlightDeck reaches IRIS administration: in-process calls to the official
/// SysAdmin API handlers of the instance (%Api.Admin for v2, Api.Admin for v1), under the current
/// user's identity and roles.
/// Constitution I and II; research R4.
/// <p>The official handlers must run with $namespace = "%SYS". The caller's %request, %response
/// and $namespace are always restored, so a FlightDeck handler can call this any number of times
/// before writing its own response.
Class FlightDeck.Admin.Client [ Abstract ]
{

/// Calls one official operation, identified by its v2 method and path.
/// <ul>
/// <li><var>method</var>: GET, PUT, POST or DELETE, as in the v2 specification.</li>
/// <li><var>path</var>: the v2 operation path, e.g. "/v2/security/roles", or "/info".</li>
/// <li><var>query</var>: optional %DynamicObject of query parameters.</li>
/// <li><var>body</var>: optional %DynamicAbstractObject sent as JSON.</li>
/// </ul>
/// The dialect is selected once per session (FlightDeck.Admin.Dialect). On the v1 dialect the
/// operation is translated by FlightDeck.Admin.V1Dialect; an operation without a v1 route answers
/// 501 with the version message, without calling IRIS. This is the only place that knows about
/// dialects.
/// <p>Outputs the HTTP status code, the parsed JSON (or "" when the body is not JSON), the raw body
/// text and the response headers by lower-case name. Returns an error %Status only when the call
/// could not be made at all; an HTTP error from the API is a successful call with status >= 400.
ClassMethod Call(method As %String, path As %String, query As %DynamicObject = "", body As %DynamicAbstractObject = "", Output status As %Integer, Output result As %DynamicAbstractObject, Output raw As %String, Output headers As %String) As %Status
{
	set method = $zconvert(method, "U")
	set status = 0, result = "", raw = ""
	kill headers
	set dialect = ##class(FlightDeck.Admin.Dialect).Current()
	if dialect = "v2" {
		quit ..Dispatch("%Api.Admin", path, method, query, body, .status, .result, .raw, .headers)
	}
	if (dialect = "v1") && ##class(FlightDeck.Admin.V1Dialect).Translate(method _ " " _ path, body, .v1Method, .v1Path, .v1Body) {
		quit ..Dispatch("Api.Admin", v1Path, v1Method, query, v1Body, .status, .result, .raw, .headers)
	}
	if dialect = "unknown" {
		// The caller cannot read %SYS, so no official handler would run for them: answer like the
		// <PROTECT> a dispatch raises (403, no administrative privilege).
		quit ..Dispatch("Api.Admin", path, method, query, body, .status, .result, .raw, .headers)
	}
	do ..Unavailable(dialect, .status, .result, .raw)
	quit $$$OK
}

/// The dialect selected for this session: "v2", "v1" (limited mode) or "none".
ClassMethod Dialect() As %String
{
	quit ##class(FlightDeck.Admin.Dialect).Current()
}

/// True unless the instance is known to expose no SysAdmin API FlightDeck speaks. A caller who cannot
/// read %SYS on a v1 instance ("unknown") is refused for missing privileges instead, by the API's 403.
ClassMethod ApiPresent() As %Boolean
{
	quit ##class(FlightDeck.Admin.Dialect).Current() '= "none"
}

/// True when some v2 operations have no route on the instance (limited mode, FR-012a).
ClassMethod Limited() As %Boolean
{
	quit ##class(FlightDeck.Admin.Dialect).Current() = "v1"
}

/// True when the instance offers the v2 operation, in whichever dialect it speaks. Callers that
/// fill a gap natively ask this instead of asking for a version (Constitution I, dialect note).
ClassMethod Has(operationId As %String) As %Boolean
{
	set dialect = ##class(FlightDeck.Admin.Dialect).Current()
	if dialect = "v2" quit 1
	if dialect = "v1" quit ##class(FlightDeck.Admin.V1Dialect).IsAvailable(operationId)
	quit 0
}

/// The version answer for an operation the instance's dialect does not have (docs/prd.md §9, message 8).
ClassMethod Unavailable(dialect As %String, Output status As %Integer, Output result As %DynamicAbstractObject, Output raw As %String)
{
	set message = $select(dialect="none":##class(FlightDeck.API.Response).#MSGNOAPI, 1:##class(FlightDeck.API.Response).#MSGVERSION)
	set status = 501
	set result = {"status":{"errors":[{"error":(message), "code":"FLIGHTDECK_UNAVAILABLE", "id":"NotAvailableInDialect"}], "summary":(message)}, "console":[], "result":{}}
	set raw = result.%ToJSON()
}

/// Low-level in-process call to a dispatcher class. Used by Call and by dialect detection only.
ClassMethod Dispatch(dispatcher As %String, path As %String, method As %String, query As %DynamicObject = "", body As %DynamicAbstractObject = "", Output status As %Integer, Output result As %DynamicAbstractObject, Output raw As %String, Output headers As %String) As %Status
{
	set status = 0, result = "", raw = ""
	kill headers
	set sc = $$$OK
	set hadRequest = $data(%request)#2, hadResponse = $data(%response)#2
	set savedRequest = $get(%request), savedResponse = $get(%response)
	// Outside a web request (installer, unit tests) some official handlers still read %session.
	set transientSession = '($data(%session)#2)
	if transientSession set %session = ##class(%CSP.Session).%New(-1, 0)
	set capture = ""
	try {
		set %request = ##class(FlightDeck.Admin.Request).%New()
		set %request.CgiEnvs("REQUEST_METHOD") = $zconvert(method, "U")
		if $isobject(query) {
			set iter = query.%GetIterator()
			while iter.%GetNext(.key, .value) {
				set %request.Data(key, 1) = value
			}
		}
		// A POST without a body is sent as JSON "{}": some official operations whose body is
		// optional (for example /v2/task/suspend) answer 415 to a request without a JSON content
		// type (verification/v1-adapter-spike.md, finding 5).
		if '$isobject(body), $listfind($listbuild("POST", "PATCH"), $zconvert(method, "U")) {
			set body = {}
		}
		if $isobject(body) {
			set content = ##class(%CSP.CharacterStream).%New()
			do content.Write(body.%ToJSON())
			do content.Rewind()
			set %request.Content = content
			do %request.SetContentType("application/json")
			set %request.CgiEnvs("CONTENT_TYPE") = "application/json"
		}
		set %response = ##class(%CSP.Response).%New()
		set protect = ""
		set capture = ##class(FlightDeck.Admin.Capture).Start()
		try {
			new $namespace
			set $namespace = "%SYS"
			set sc = $classmethod(dispatcher, "DispatchRequest", path, $zconvert(method, "U"), 1)
		} catch inner {
			// A user who cannot even read %SYS holds no administrative privilege: answer like the
			// API's own 403 instead of failing the call.
			if inner.Name = "<PROTECT>" {
				set protect = inner.DisplayString()
			} else {
				set sc = inner.AsStatus()
			}
		}
		set raw = ##class(FlightDeck.Admin.Capture).Stop(capture)
		set capture = ""
		set status = +%response.Status
		set:status=0 status = 200
		set name = ""
		for {
			set name = $order(%response.Headers(name))
			quit:name=""
			set headers($zconvert(name, "L")) = %response.Headers(name)
		}
		if protect '= "" set status = 403
		if protect '= "" set raw = "{""status"":{""errors"":[{""error"":"""_$zconvert(protect, "O", "JSON")_"""}]}}"
		if $extract($zstrip(raw, "<W")) ? 1(1"{",1"[") {
			try {
				set result = ##class(%DynamicAbstractObject).%FromJSON(raw)
			} catch {
				set result = ""
			}
		}
		if $$$ISERR(sc), status < 400 {
			set status = 500
		}
	} catch ex {
		if capture '= "" do ##class(FlightDeck.Admin.Capture).Stop(capture)
		set sc = ex.AsStatus()
	}
	if hadRequest { set %request = savedRequest } else { kill %request }
	if hadResponse { set %response = savedResponse } else { kill %response }
	if transientSession kill %session
	quit sc
}

/// Convenience: GET with optional query; returns the "result" member or "".
ClassMethod Get(path As %String, query As %DynamicObject = "", Output status As %Integer, Output raw As %String) As %DynamicAbstractObject
{
	set sc = ..Call("GET", path, query, "", .status, .json, .raw)
	if $$$ISERR(sc) {
		set status = 500, raw = $system.Status.GetErrorText(sc)
		quit ""
	}
	quit $select($isobject(json):json.%Get("result"), 1:"")
}

/// The first error text in an official error body, or the raw text.
ClassMethod ErrorText(json As %DynamicAbstractObject, raw As %String) As %String
{
	set text = $extract(raw, 1, 2000)
	try {
		set errors = json.status.errors
		if $isobject(errors), errors.%Size() > 0 {
			set text = errors.%Get(0).error
		}
	} catch {}
	quit text
}

}

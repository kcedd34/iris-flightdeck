/// The only way FlightDeck reaches IRIS administration: in-process calls to the official
/// SysAdmin API handlers (%Api.Admin), under the current user's identity and roles.
/// Constitution I and II; research R4.
/// <p>The official handlers must run with $namespace = "%SYS". The caller's %request, %response
/// and $namespace are always restored, so a FlightDeck handler can call this any number of times
/// before writing its own response.
Class FlightDeck.Admin.Client [ Abstract ]
{

/// Calls one official operation.
/// <ul>
/// <li><var>method</var>: GET, PUT, POST or DELETE.</li>
/// <li><var>path</var>: the operation path as in the spec, e.g. "/v2/security/roles".</li>
/// <li><var>query</var>: optional %DynamicObject of query parameters.</li>
/// <li><var>body</var>: optional %DynamicAbstractObject sent as JSON.</li>
/// </ul>
/// Outputs the HTTP status code, the parsed JSON (or "" when the body is not JSON) and the raw
/// body text (max 32 KB). Returns an error %Status only when the call could not be made at all;
/// an HTTP error from the API is a successful call with status >= 400. <var>headers</var> holds the
/// response headers by lower-case name.
ClassMethod Call(method As %String, path As %String, query As %DynamicObject = "", body As %DynamicAbstractObject = "", Output status As %Integer, Output result As %DynamicAbstractObject, Output raw As %String, Output headers As %String) As %Status
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
			set sc = ##class(%Api.Admin).DispatchRequest(path, $zconvert(method, "U"), 1)
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

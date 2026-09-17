/// The REST test executor (UC04, RN-FD-08, feature 002 research R8 as revised by spike T-EXEC-1,
/// verification/rest-executor-spike-2026.2.md).
/// <p>Confined by construction: the client supplies only a path relative to this instance; scheme,
/// host and port are never taken from it and nothing leaves the process. The request is dispatched
/// in-process to the REST web application that serves the path, as the signed-in user, without any
/// credential. Roles are kept or cleared to login roles, never set to another value: FlightDeck code
/// never sets $ROLES to a non-empty value (spike finding 2; FlightDeck.Test.NoRolesAssignment).
Class FlightDeck.Rest.Executor [ Abstract ]
{

Parameter BODYLIMIT = 1048576;

Parameter METHODS = "GET,HEAD,OPTIONS,POST,PUT,PATCH,DELETE";

/// Validates a TestRequest. Returns "" or {status, code, message}.
ClassMethod Validate(request As %DynamicObject) As %DynamicObject
{
	if '$isobject(request) quit {"status":400, "code":"BAD_REQUEST", "message":"A test request is required."}
	set method = $zconvert(request.method, "U")
	if '$listfind($listfromstring(..#METHODS), method) quit {"status":400, "code":"BAD_REQUEST", "message":("Method "_request.method_" is not supported.")}
	set path = request.path
	if '..PathInsideInstance(path) quit {"status":400, "code":"TARGET_OUTSIDE_INSTANCE", "message":"Test requests go only to this instance: give a path that starts with a single / and names no host, scheme or parent directory."}
	if $isobject(request.headers) {
		set iter = request.headers.%GetIterator()
		while iter.%GetNext(.name) {
			if $listfind($listbuild("authorization", "cookie", "proxy-authorization", "host"), $zconvert(name, "L")) {
				return {"status":400, "code":"CREDENTIAL_HEADER", "message":("Header "_name_" is not allowed: test requests run as the signed-in user and always target this instance.")}
			}
		}
	}
	quit ""
}

/// A path relative to this instance: starts with exactly one "/", no scheme or host, no backslash,
/// no NUL or control characters, no "." or ".." segment (literal or percent-encoded).
ClassMethod PathInsideInstance(path As %String) As %Boolean
{
	quit:path="" 0
	quit:$extract(path)'="/" 0
	quit:$extract(path, 1, 2)="//" 0
	quit:path["\" 0
	quit:path["://" 0
	if $locate(path, "[\x00-\x1F\x7F]") quit 0
	set decoded = path
	for pass=1:1:3 { set decoded = $zconvert(decoded, "I", "URL") }
	quit:decoded["\" 0
	quit:$extract(decoded, 1, 2)="//" 0
	quit:$zconvert(decoded, "L")["://" 0
	for i=1:1:$length(decoded, "/") {
		set segment = $piece($piece(decoded, "/", i), "?", 1)
		if (segment = ".") || (segment = "..") return 0
	}
	quit 1
}

/// Resolves the web application serving a path by longest name prefix, through the official API.
/// Returns the official detail object (plus Name) or "" with failure {status, code, message}.
ClassMethod Resolve(path As %String, Output failure As %DynamicObject) As %DynamicObject
{
	set failure = ""
	set list = ##class(FlightDeck.Admin.Client).Get("/v2/web-apps", {"maxRows":1000}, .status, .raw)
	if status '= 200 {
		set failure = {"status":(status), "code":($select(status=403:"FORBIDDEN", 1:"UPSTREAM_REJECTED")), "message":(##class(FlightDeck.Admin.Client).ErrorText("", raw))}
		if status = 403 set failure.message = ##class(FlightDeck.API.Response).RequiresMessage(##class(FlightDeck.Capability.Map).Operation("GET /v2/web-apps").requires)
		quit ""
	}
	set best = "", clean = $piece(path, "?", 1)
	set iter = list.%GetIterator()
	while iter.%GetNext(, .app) {
		set name = app.Name
		if (clean = name) || ($extract(clean, 1, $length(name) + 1) = (name _ "/")) {
			if $length(name) > $length(best) set best = name
		}
	}
	if best = "" {
		set failure = {"status":404, "code":"NO_WEB_APPLICATION", "message":("No web application on this instance serves "_clean_".")}
		quit ""
	}
	set detail = ##class(FlightDeck.Admin.Client).Get("/v2/web-app", {"name":(best)}, .status, .raw)
	if status '= 200 {
		set failure = {"status":(status), "code":"UPSTREAM_REJECTED", "message":(##class(FlightDeck.Admin.Client).ErrorText("", raw))}
		quit ""
	}
	set detail.Name = best
	quit detail
}

/// Runs a validated test request. Returns an ExecuteResponse, or "" with failure.
ClassMethod Run(request As %DynamicObject, Output failure As %DynamicObject) As %DynamicObject
{
	set failure = ..Validate(request)
	quit:$isobject(failure) ""
	set app = ..Resolve(request.path, .failure)
	quit:$isobject(failure) ""
	set resolved = {"webApplication":(app.Name), "namespace":(app.NameSpace), "dispatchClass":(app.DispatchClass)}
	if 'app.Enabled {
		set failure = {"status":422, "code":"APPLICATION_DISABLED", "message":("Web application "_app.Name_" is disabled: the instance would not serve this request.")}
		quit ""
	}
	if (app.DispatchClass = "") || '..IsRestDispatcher(app.DispatchClass, app.NameSpace) {
		set failure = {"status":422, "code":"NOT_A_REST_SERVICE", "message":("Web application "_app.Name_" is not served by a REST dispatch class, so it cannot be tested in-process. Only REST services can be tested.")}
		quit ""
	}
	if (app.Resource '= "") && '$system.Security.Check(app.Resource, "USE") {
		set response = ..Response(403, "", "", resolved, 0, "login-only", [])
		set response.body = "Web application "_app.Name_" requires Use on "_app.Resource_", which you do not hold."
		set response.bodySize = $length(response.body)
		quit response
	}
	set login = ..LoginRoles()
	set added = ..Minus($roles, login)
	set grants = ..Grants(app.MatchRoles, login)
	set keep = (added = "") || (..Minus(added, grants) = "")
	set mode = $select(keep:"current-kept", 1:"login-only")
	set held = $select(keep:$roles, 1:login)
	set notApplied = []
	set ptr = 0, grantList = $listfromstring(grants)
	while $listnext(grantList, ptr, role) { if (role '= "") && '$listfind($listfromstring(held), role) do notApplied.%Push(role) }
	set started = $zhorolog
	set outcome = ..Dispatch(request, app, keep)
	set elapsed = $normalize(($zhorolog - started) * 1000, 1)
	set response = ..Response(outcome.status, outcome.body, outcome.contentType, resolved, elapsed, mode, notApplied)
	set response.headers = outcome.headers
	quit response
}

ClassMethod Response(status As %Integer, body As %String, contentType As %String, resolved As %DynamicObject, elapsed As %Numeric, mode As %String, notApplied As %DynamicArray) As %DynamicObject
{
	set size = $length(body)
	set response = {"headers":{}, "resolved":(resolved), "rolesMode":(mode), "grantsNotApplied":(notApplied)}
	do response.%Set("status", status, "number")
	do response.%Set("elapsedMs", elapsed, "number")
	do response.%Set("body", $extract(body, 1, ..#BODYLIMIT))
	do response.%Set("bodySize", size, "number")
	do response.%Set("truncated", size > ..#BODYLIMIT, "boolean")
	do response.%Set("contentType", contentType, $select(contentType="":"null", 1:"string"))
	quit response
}

/// The dispatch itself, in its own frame so NEW $ROLES and NEW $NAMESPACE end on return.
ClassMethod Dispatch(request As %DynamicObject, app As %DynamicObject, keepRoles As %Boolean) As %DynamicObject
{
	set out = {"status":200, "body":"", "contentType":"", "headers":{}}
	set savedRequest = $get(%request), savedResponse = $get(%response), savedSession = $get(%session)
	set capture = ""
	try {
		set %request = ##class(FlightDeck.Admin.Request).%New()
		set method = $zconvert(request.method, "U")
		set %request.CgiEnvs("REQUEST_METHOD") = method
		set relative = $extract($piece(request.path, "?", 1), $length(app.Name) + 1, *)
		set:relative="" relative = "/"
		set %request.URL = $piece(request.path, "?", 1)
		// Query: from the path and from the request's query object.
		set pathQuery = $piece(request.path, "?", 2, *)
		for i=1:1:$length(pathQuery, "&") {
			set pair = $piece(pathQuery, "&", i)
			continue:pair=""
			set %request.Data($zconvert($piece(pair, "=", 1), "I", "URL"), 1) = $zconvert($piece(pair, "=", 2, *), "I", "URL")
		}
		if $isobject(request.query) {
			set iter = request.query.%GetIterator()
			while iter.%GetNext(.key, .value) { set %request.Data(key, 1) = value }
		}
		set contentType = ""
		if $isobject(request.headers) {
			set iter = request.headers.%GetIterator()
			while iter.%GetNext(.name, .value) {
				set %request.CgiEnvs("HTTP_"_$translate($zconvert(name, "U"), "-", "_")) = value
				if $zconvert(name, "L") = "content-type" set contentType = value
			}
		}
		if (request.body '= "") && $listfind($listbuild("POST", "PUT", "PATCH", "DELETE"), method) {
			set content = ##class(%CSP.CharacterStream).%New()
			do content.Write(request.body)
			do content.Rewind()
			set %request.Content = content
			set:contentType="" contentType = "application/json"
			do %request.SetContentType(contentType)
			set %request.CgiEnvs("CONTENT_TYPE") = contentType
		}
		set %response = ##class(%CSP.Response).%New()
		// A transient session: the target application never sees or changes FlightDeck's session.
		set %session = ##class(%CSP.Session).%New(-1, 0)
		set capture = ##class(FlightDeck.Admin.Capture).Start()
		set frame = ..DispatchFrame(app.DispatchClass, app.NameSpace, relative, method, keepRoles)
		set raw = ##class(FlightDeck.Admin.Capture).Stop(capture)
		set capture = ""
		set status = +%response.Status
		set:status=0 status = 200
		if frame.protect set status = 403, raw = frame.message
		set out.status = status, out.body = raw, out.contentType = %response.ContentType
		set name = ""
		for { set name = $order(%response.Headers(name)) quit:name=""  do out.headers.%Set(name, %response.Headers(name)) }
		if %response.ContentType '= "" do out.headers.%Set("Content-Type", %response.ContentType _ $select(%response.CharSet'="":"; charset="_%response.CharSet, 1:""))
	} catch ex {
		if capture '= "" try { do ##class(FlightDeck.Admin.Capture).Stop(capture) } catch {}
		set out.status = $select(ex.Name="<PROTECT>":403, 1:500), out.body = ex.DisplayString()
	}
	set %request = savedRequest, %response = savedResponse
	if $isobject(savedSession) { set %session = savedSession } else { kill %session }
	quit out
}

/// NEW $ROLES / $NAMESPACE live only in this frame. Roles are cleared to login roles or left as
/// they are; never set to another value.
ClassMethod DispatchFrame(class As %String, namespace As %String, path As %String, method As %String, keepRoles As %Boolean) As %DynamicObject
{
	set out = {"protect":0, "message":""}
	try {
		new $roles, $namespace
		if 'keepRoles set $roles = ""
		set $namespace = namespace
		set sc = $classmethod(class, "DispatchRequest", path, method, 1)
		// %CSP.REST reports a <PROTECT> inside the handler as an error status, with HTTP 200 left in
		// %response (spike T-EXEC-1, finding 5).
		if $$$ISERR(sc) && ($system.Status.GetErrorText(sc) [ "<PROTECT>") {
			set out.protect = 1, out.message = "Your roles cannot read what this request needs: "_$system.Status.GetErrorText(sc)
		}
	} catch ex {
		if ex.Name = "<PROTECT>" {
			set out.protect = 1
			set out.message = "Your roles cannot read what this request needs: "_ex.DisplayString()
		} else {
			throw ex
		}
	}
	quit out
}

/// The login roles of the signed-in user (added roles removed in a throwaway frame).
ClassMethod LoginRoles() As %String
{
	new $roles
	set $roles = ""
	quit $roles
}

/// Roles a target application's MatchRoles grants this user: entries whose MatchRole is empty or held.
ClassMethod Grants(matchRoles As %DynamicArray, loginRoles As %String) As %String
{
	set out = ""
	quit:'$isobject(matchRoles) out
	set iter = matchRoles.%GetIterator()
	while iter.%GetNext(, .match) {
		if (match.MatchRole '= "") && '$listfind($listfromstring(loginRoles), match.MatchRole) continue
		set targets = match.TargetRoles.%GetIterator()
		while targets.%GetNext(, .role) { set:'$listfind($listfromstring(out), role) out = out _ $select(out="":"", 1:",") _ role }
	}
	quit out
}

/// Comma list a minus comma list b.
ClassMethod Minus(a As %String, b As %String) As %String
{
	set out = "", bl = $listfromstring(b), al = $listfromstring(a), ptr = 0
	while $listnext(al, ptr, item) { if (item '= "") && '$listfind(bl, item) set out = out _ $select(out="":"", 1:",") _ item }
	quit out
}

ClassMethod IsRestDispatcher(class As %String, namespace As %String) As %Boolean
{
	set result = 0
	try {
		new $namespace
		set $namespace = namespace
		set result = ##class(%Dictionary.CompiledClass).%ExistsId(class) && $classmethod(class, "%Extends", "%CSP.REST")
	} catch {
		set result = 0
	}
	quit result
}

}

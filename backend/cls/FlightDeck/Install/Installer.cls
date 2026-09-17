/// Installer invoked by IPM (module.xml). Everything it creates beyond FlightDeck's own two web
/// applications (declared in module.xml, the Constitution I bootstrap exception) goes through the
/// official SysAdmin API via FlightDeck.Admin.Client.
/// <p>Every step is idempotent and prints one line. A failure prints
/// "FLIGHTDECK INSTALL FAILED: &lt;step&gt;: &lt;IRIS error text&gt;" and returns the error, so IPM
/// fails loudly and the line shows in the container log.
Class FlightDeck.Install.Installer [ Abstract ]
{

Parameter RUNTIMEROLE = "FlightDeck_Runtime";

/// Runs before IPM activates the web applications: version floor and runtime role.
ClassMethod Prepare() As %Status
{
	set sc = ..Step("capture", ..DeployCapture())
	quit:$$$ISERR(sc) sc
	set sc = ..Step("version", ..CheckVersion())
	quit:$$$ISERR(sc) sc
	quit ..Step("role", ..EnsureRuntimeRole())
}

/// Runs after activation: web application check and optional demo provisioning.
ClassMethod Run(demo As %Boolean = 0) As %Status
{
	set sc = ..Step("web applications", ..VerifyWebApps())
	quit:$$$ISERR(sc) sc
	if +demo {
		set sc = ..Step("demo", ##class(FlightDeck.Install.Demo).Provision())
		quit:$$$ISERR(sc) sc
	}
	write "FlightDeck: install complete (demo=", +demo, ")", !
	quit $$$OK
}

/// Installer bootstrap (plan Complexity Tracking): copies FlightDeck.Admin.Capture into %SYS.
/// Official handlers run in %SYS, and I/O redirection resolves its mnemonic routine in the current
/// namespace, so the capture routine must exist there too. It holds only the redirect entry points.
ClassMethod DeployCapture() As %Status
{
	if $namespace = "%SYS" quit $$$OK
	set file = ##class(%File).TempFilename("xml")
	set sc = $system.OBJ.Export("FlightDeck.Admin.Capture.cls", file, "-d")
	quit:$$$ISERR(sc) sc
	try {
		new $namespace
		set $namespace = "%SYS"
		set sc = $system.OBJ.Load(file, "ck-d")
	} catch ex {
		set sc = ex.AsStatus()
	}
	do ##class(%File).Delete(file)
	quit:$$$ISERR(sc) sc
	write "FlightDeck: capture routine deployed to %SYS", !
	quit $$$OK
}

/// FR-012a: the instance must expose the SysAdmin API. v2 (IRIS 2026.2+) runs in full; v1
/// (IRIS 2026.1) runs in limited mode. Detected by the API itself, never by parsing the version string.
ClassMethod CheckVersion() As %Status
{
	do ##class(FlightDeck.Admin.Dialect).Reset()
	if '##class(FlightDeck.Admin.Client).ApiPresent() {
		quit $$$ERROR($$$GeneralError, "Requires the SysAdmin API, IRIS 2026.1 or later (detected "_$zversion_")")
	}
	write "FlightDeck: SysAdmin API ", ##class(FlightDeck.Admin.Client).Dialect(), " present"
	write $select(##class(FlightDeck.Admin.Client).Limited():" (limited mode: operations the instance does not offer are shown unavailable)", 1:""), !
	quit $$$OK
}

/// FlightDeck_Runtime grants read on the database holding FlightDeck's code, and nothing else.
/// Both web apps grant it through MatchRoles, so any signed-in administrator can run the portal
/// code without a public grant (research R4).
ClassMethod EnsureRuntimeRole() As %Status
{
	set sc = ..CodeDatabaseResource(.resource, .database)
	quit:$$$ISERR(sc) sc
	if resource = "" quit $$$ERROR($$$GeneralError, "Database "_database_" has no resource")
	set body = {
		"Description": "FlightDeck runtime: read access to the FlightDeck code database only. Granted inside the FlightDeck web applications.",
		"Resources": [ {"Name":(resource), "Permissions":"R"} ]
	}
	set existing = ##class(FlightDeck.Admin.Client).Get("/v2/security/role", {"name":(..#RUNTIMEROLE)}, .status, .raw)
	set outcome = $select(status=200:"updated", 1:"created")
	set sc = ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/security/role", {"name":(..#RUNTIMEROLE)}, body, .status, .json, .raw)
	quit:$$$ISERR(sc) sc
	if status >= 300 quit ..ApiError("PUT /v2/security/role", status, raw, json)
	write "FlightDeck: role ", ..#RUNTIMEROLE, " ", outcome, " (", resource, ":R)", !
	quit $$$OK
}

/// The resource of the database holding FlightDeck's code, through the official namespace,
/// database and database-dir operations. Where the instance has none of them (v1 dialect), the
/// installer bootstrap reads it natively (plan Complexity Tracking).
ClassMethod CodeDatabaseResource(Output resource As %String, Output database As %String) As %Status
{
	set resource = "", database = ""
	if '##class(FlightDeck.Admin.Client).Has("GET /v2/namespace") || '##class(FlightDeck.Admin.Client).Has("GET /v2/database") || '##class(FlightDeck.Admin.Client).Has("GET /v2/database-dir") {
		quit ##class(FlightDeck.Native.Databases).CodeDatabaseResource($namespace, .resource, .database)
	}
	set ns = ##class(FlightDeck.Admin.Client).Get("/v2/namespace", {"name":($namespace)}, .status, .raw)
	if status '= 200 quit ..ApiError("GET /v2/namespace", status, raw)
	set database = ns.Routines
	set db = ##class(FlightDeck.Admin.Client).Get("/v2/database", {"name":(database)}, .status, .raw)
	if status '= 200 quit ..ApiError("GET /v2/database", status, raw)
	set dir = ##class(FlightDeck.Admin.Client).Get("/v2/database-dir", {"dir":(db.Directory)}, .status, .raw)
	if status '= 200 quit ..ApiError("GET /v2/database-dir", status, raw)
	set resource = dir.ResourceName
	quit $$$OK
}

/// FlightDeck's own web applications as module.xml declares them: name, the authentication bit the
/// portal needs, and whether the runtime role must stay in MatchRoles.
ClassMethod DeclaredApplications() As %DynamicArray
{
	quit [
		{"name":"/api/flightdeck", "requiredAuthBits":32, "runtimeRole":(..#RUNTIMEROLE)},
		{"name":"/flightdeck", "requiredAuthBits":64, "runtimeRole":(..#RUNTIMEROLE)}
	]
}

/// Verifies the declared applications through the official API and records them for server-side
/// self-protection (feature 002 research R7). The record is keyed by application name, holds the
/// namespace the API reports, and is rewritten on every run (idempotent).
ClassMethod VerifyWebApps() As %Status
{
	set status = 200, raw = "", recorded = []
	set iter = ..DeclaredApplications().%GetIterator()
	while iter.%GetNext(, .app) {
		set result = ##class(FlightDeck.Admin.Client).Get("/v2/web-app", {"name":(app.name)}, .status, .raw)
		if status '= 200 quit
		do app.%Set("namespace", result.NameSpace)
		do recorded.%Push(app)
		write "FlightDeck: web application ", app.name, " present", !
	}
	if status '= 200 quit ..ApiError("GET /v2/web-app", status, raw)
	quit ..RecordApplications(recorded)
}

ClassMethod RecordApplications(applications As %DynamicArray) As %Status
{
	kill ^FlightDeck.Install("applications")
	set iter = applications.%GetIterator()
	while iter.%GetNext(, .app) {
		set ^FlightDeck.Install("applications", app.name) = app.%ToJSON()
	}
	write "FlightDeck: recorded ", applications.%Size(), " web applications for self-protection", !
	quit $$$OK
}

ClassMethod ApiError(operation As %String, status As %Integer, raw As %String, json As %DynamicAbstractObject = "") As %Status
{
	quit $$$ERROR($$$GeneralError, operation_" returned HTTP "_status_": "_##class(FlightDeck.Admin.Client).ErrorText(json, raw))
}

ClassMethod Step(name As %String, sc As %Status) As %Status
{
	if $$$ISERR(sc) {
		write !, "FLIGHTDECK INSTALL FAILED: ", name, ": ", $system.Status.GetErrorText(sc), !
	}
	quit sc
}

}

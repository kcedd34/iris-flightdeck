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

/// FR-012a: SysAdmin API v2 must exist. Detected by capability (the v2 dispatcher), never by
/// parsing the version string.
ClassMethod CheckVersion() As %Status
{
	if '##class(%Dictionary.CompiledClass).%ExistsId("%Api.Admin.Dispatch.v2") {
		quit $$$ERROR($$$GeneralError, "Requires IRIS 2026.2 (detected "_$zversion_")")
	}
	write "FlightDeck: SysAdmin API v2 present", !
	quit $$$OK
}

/// FlightDeck_Runtime grants read on the database holding FlightDeck's code, and nothing else.
/// Both web apps grant it through MatchRoles, so any signed-in administrator can run the portal
/// code without a public grant (research R4).
ClassMethod EnsureRuntimeRole() As %Status
{
	set ns = ##class(FlightDeck.Admin.Client).Get("/v2/namespace", {"name":($namespace)}, .status, .raw)
	if status '= 200 quit ..ApiError("GET /v2/namespace", status, raw)
	set db = ##class(FlightDeck.Admin.Client).Get("/v2/database", {"name":(ns.Routines)}, .status, .raw)
	if status '= 200 quit ..ApiError("GET /v2/database", status, raw)
	set dir = ##class(FlightDeck.Admin.Client).Get("/v2/database-dir", {"dir":(db.Directory)}, .status, .raw)
	if status '= 200 quit ..ApiError("GET /v2/database-dir", status, raw)
	set resource = dir.ResourceName
	if resource = "" quit $$$ERROR($$$GeneralError, "Database "_ns.Routines_" ("_db.Directory_") has no resource")
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

ClassMethod VerifyWebApps() As %Status
{
	for app = "/api/flightdeck", "/flightdeck" {
		set result = ##class(FlightDeck.Admin.Client).Get("/v2/web-app", {"name":(app)}, .status, .raw)
		if status '= 200 quit
		write "FlightDeck: web application ", app, " present", !
	}
	if status '= 200 quit ..ApiError("GET /v2/web-app", status, raw)
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

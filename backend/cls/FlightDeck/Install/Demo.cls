/// Demonstration objects for a fresh container install (FR-044, research R14).
/// <p>Constitution I: every object is created through the official SysAdmin API via
/// FlightDeck.Admin.Client. No Security.* or Config.* class is used here.
/// <p>Idempotent: each object is read first and created only when the API answers 404.
/// Every object carries the FD_Demo / fd-demo / "FD Demo" prefix so palette search finds it.
/// The wallet collection has no secrets.
Class FlightDeck.Install.Demo [ Abstract ]
{

ClassMethod Provision() As %Status
{
	set sc = $$$OK
	for step = "Resources", "Roles", "WebApp", "Tasks", "Wallet" {
		set sc = $classmethod($classname(), step)
		quit:$$$ISERR(sc)
	}
	quit sc
}

ClassMethod Resources() As %Status
{
	set sc = ..Ensure("resource", "/v2/security/resource", "FD_Demo_Reports", {"Description":"FlightDeck demo: reports data", "PublicPermission":"U"})
	quit:$$$ISERR(sc) sc
	quit ..Ensure("resource", "/v2/security/resource", "FD_Demo_Billing", {"Description":"FlightDeck demo: billing data", "PublicPermission":"U"})
}

ClassMethod Roles() As %Status
{
	set sc = ..Ensure("role", "/v2/security/role", "FD_Demo_Operator", {
		"Description": "FlightDeck demo: operates reports",
		"Resources": [ {"Name":"FD_Demo_Reports", "Permissions":"RW"} ]
	})
	quit:$$$ISERR(sc) sc
	quit ..Ensure("role", "/v2/security/role", "FD_Demo_Auditor", {
		"Description": "FlightDeck demo: reads reports and billing",
		"Resources": [ {"Name":"FD_Demo_Reports", "Permissions":"R"}, {"Name":"FD_Demo_Billing", "Permissions":"R"} ]
	})
}

/// Intentionally unauthenticated, so the Web applications screen shows the exposure warning.
ClassMethod WebApp() As %Status
{
	quit ..Ensure("web-app", "/v2/web-app", "/csp/fd-demo", {
		"Description": "FlightDeck demo: intentionally unauthenticated",
		"NameSpace": ($namespace),
		"Enabled": true,
		"AutheEnabled": 64
	})
}

ClassMethod Tasks() As %Status
{
	set existing = ##class(FlightDeck.Admin.Client).Get("/v2/tasks", {"filter":"FD Demo", "maxRows":100}, .status, .raw)
	if status '= 200 quit ..ApiError("GET /v2/tasks", status, raw)
	set names = ""
	if $isobject(existing) {
		set iter = existing.%GetIterator()
		while iter.%GetNext(, .task) { set names(task.Name) = "" }
	}
	for spec = $listbuild("FD Demo daily no-op", "02:00:00", 0, "Runs every day and succeeds."),
	           $listbuild("FD Demo nightly no-op", "03:00:00", 0, "Runs every night and succeeds."),
	           $listbuild("FD Demo failing task", "04:00:00", 1, "Runs every day and fails on purpose, to show a failed run.") {
		set name = $list(spec, 1)
		if $data(names(name)) {
			write "FlightDeck demo: task ", name, " exists", !
			continue
		}
		set body = {
			"Name": (name), "Description": ($list(spec, 4)),
			"TaskClass": "FlightDeck.Demo.NoopTask", "NameSpace": ($namespace), "RunAsUser": ($username),
			"TimePeriod": "Daily", "TimePeriodEvery": 1, "TimePeriodDay": "",
			"DailyFrequency": "Once", "DailyFrequencyTime": "", "DailyIncrement": "",
			"DailyStartTime": ($list(spec, 2)), "DailyEndTime": ($list(spec, 2)),
			"StartDate": ($zdate($horolog, 3)), "EndDate": "",
			"Priority": "Normal", "MirrorStatus": "Any", "RunAfterGUID": "",
			"EmailOnCompletion": [], "EmailOnError": [], "EmailOnExpiration": [], "EmailOutput": false,
			"Expires": false, "ExpiresDays": "", "ExpiresHours": "", "ExpiresMinutes": "",
			"OpenOutputFile": false, "OutputDirectory": "", "OutputFilename": "", "OutputFileIsBinary": false,
			"SuspendOnError": false, "SuspendTerminated": false, "IsBatch": false, "RescheduleOnStart": true,
			"Settings": {"Fail": ($list(spec, 3))}
		}
		set sc = ##class(FlightDeck.Admin.Client).Call("POST", "/v2/task", , body, .status, .json, .raw)
		quit:$$$ISERR(sc)
		if status >= 300 {
			set sc = ..ApiError("POST /v2/task ("_name_")", status, raw, json)
			quit
		}
		write "FlightDeck demo: task ", name, " created", !
	}
	quit $get(sc, $$$OK)
}

/// Collection only, never a secret (Constitution VI).
ClassMethod Wallet() As %Status
{
	set list = ##class(FlightDeck.Admin.Client).Get("/v2/wallet/collections", , .status, .raw)
	if status = 404 {
		write "FlightDeck demo: wallet-collection FD_Demo_Vault skipped (Wallet API not available on this instance)", !
		quit $$$OK
	}
	quit ..Ensure("wallet-collection", "/v2/wallet/collection", "FD_Demo_Vault", {"UseResource":"FD_Demo_Reports", "EditResource":"FD_Demo_Reports"})
}

/// GET ?name=…; 404 creates with PUT ?name=…; 200 leaves the object as it is.
ClassMethod Ensure(kind As %String, path As %String, name As %String, body As %DynamicObject) As %Status
{
	do ##class(FlightDeck.Admin.Client).Get(path, {"name":(name)}, .status, .raw)
	if status = 200 {
		write "FlightDeck demo: ", kind, " ", name, " exists", !
		quit $$$OK
	}
	if status '= 404 quit ..ApiError("GET "_path_" ("_name_")", status, raw)
	set sc = ##class(FlightDeck.Admin.Client).Call("PUT", path, {"name":(name)}, body, .status, .json, .raw)
	quit:$$$ISERR(sc) sc
	if status >= 300 quit ..ApiError("PUT "_path_" ("_name_")", status, raw, json)
	write "FlightDeck demo: ", kind, " ", name, " created", !
	quit $$$OK
}

ClassMethod ApiError(operation As %String, status As %Integer, raw As %String, json As %DynamicAbstractObject = "") As %Status
{
	quit ##class(FlightDeck.Install.Installer).ApiError(operation, status, raw, json)
}

}

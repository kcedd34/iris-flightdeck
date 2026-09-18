/// Demonstration objects for a fresh container install (FR-044, research R14).
/// <p>Constitution I: every object is created through the official SysAdmin API via
/// FlightDeck.Admin.Client. No Security.* or Config.* class is used here.
/// <p>Idempotent: each object is read first and created only when the API answers 404.
/// Every object carries the FD_Demo / fd-demo / "FD Demo" prefix so palette search finds it.
/// <p>No user is created here: a user needs a password, and the installer creates no credential
/// (Constitution II). The demo accounts that hold these roles are created by the end-to-end setup,
/// which owns its own test credentials.
Class FlightDeck.Install.Demo [ Abstract ]
{

ClassMethod Provision() As %Status
{
	set sc = $$$OK
	for step = "Resources", "Roles", "RoleChain", "WebApp", "Tasks", "Wallet", "WalletSecret" {
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

/// A three-level chain, so the effective-privilege panel has an inherited grant to explain
/// (feature 003 US1): FD_Demo_L1 grants FD_Demo_L2, which grants FD_Demo_L3, which grants
/// FD_Demo_Billing. Only the deepest role names a resource, so the chain must be walked to see it.
ClassMethod RoleChain() As %Status
{
	set sc = ..Ensure("role", "/v2/security/role", "FD_Demo_L3", {
		"Description": "FlightDeck demo: level 3, grants billing data",
		"Resources": [ {"Name":"FD_Demo_Billing", "Permissions":"U"} ]
	})
	quit:$$$ISERR(sc) sc
	set sc = ..Ensure("role", "/v2/security/role", "FD_Demo_L2", {
		"Description": "FlightDeck demo: level 2, inherits level 3",
		"GrantedRoles": ["FD_Demo_L3"]
	})
	quit:$$$ISERR(sc) sc
	quit ..Ensure("role", "/v2/security/role", "FD_Demo_L1", {
		"Description": "FlightDeck demo: level 1, inherits level 2",
		"GrantedRoles": ["FD_Demo_L2"]
	})
}

/// Two demo applications: one intentionally unauthenticated, so the Web applications screen shows
/// the exposure warning, and one protected by FD_Demo_Reports, so its inspector links the roles that
/// grant that resource (feature 002, UC03 scenario 2).
ClassMethod WebApp() As %Status
{
	set sc = ..Ensure("web-app", "/v2/web-app", "/csp/fd-demo", {
		"Description": "FlightDeck demo: intentionally unauthenticated",
		"NameSpace": ($namespace),
		"Enabled": true,
		"AutheEnabled": 64
	})
	quit:$$$ISERR(sc) sc
	quit ..Ensure("web-app", "/v2/web-app", "/csp/fd-demo-reports", {
		"Description": "FlightDeck demo: protected by FD_Demo_Reports",
		"NameSpace": ($namespace),
		"Enabled": true,
		"AutheEnabled": 32,
		"Resource": "FD_Demo_Reports"
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
			// Tomorrow: the 2026.1 API rejects a start date and time already past (the daily times are
			// fixed), and a daily task's first run is tomorrow's anyway.
			"StartDate": ($zdate($horolog + 1, 3)), "EndDate": "",
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

/// One secret in the demo collection, so the wallet screens have something that is never displayed
/// (feature 003 US3). The value is a fixed demonstration string, not a credential of any system.
ClassMethod WalletSecret() As %Status
{
	set list = ##class(FlightDeck.Admin.Client).Get("/v2/wallet/secrets", {"collection":"FD_Demo_Vault"}, .status, .raw)
	if status = 404 {
		write "FlightDeck demo: wallet-secret skipped (Wallet API not available on this instance)", !
		quit $$$OK
	}
	if status '= 200 quit ..ApiError("GET /v2/wallet/secrets", status, raw)
	if $isobject(list) {
		set iter = list.%GetIterator()
		while iter.%GetNext(, .secret) {
			if (secret.Name = "FD_Demo_Token") || (secret.Name = "FD_Demo_Vault.FD_Demo_Token") {
				write "FlightDeck demo: wallet-secret FD_Demo_Token exists", !
				quit
			}
		}
		if $data(secret) && $isobject(secret), (secret.Name = "FD_Demo_Token") || (secret.Name = "FD_Demo_Vault.FD_Demo_Token") quit $$$OK
	}
	set body = {"Type":"%Wallet.KeyValue", "WalletSecretConfig":{"Secret":"flightdeck-demonstration-value"}}
	// The official API names a secret "<collection>.<secret>" in a single parameter.
	set sc = ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/wallet/secret", {"name":"FD_Demo_Vault.FD_Demo_Token"}, body, .status, .json, .raw)
	quit:$$$ISERR(sc) sc
	if (status = 400) || (status = 501) {
		// The secret configuration of %Wallet.KeyValue differs between API versions: IRIS 2026.1
		// requires AllowedHosts, RequireTLS and an object Usage and Secret (verification/README.md),
		// so on that version FlightDeck declines the write (501) instead of guessing the shape. The
		// demo skips it with the platform's own message rather than failing the install over a
		// fixture.
		write "FlightDeck demo: wallet-secret skipped (", ##class(FlightDeck.Admin.Client).ErrorText(json, raw), ")", !
		quit $$$OK
	}
	if status >= 300 quit ..ApiError("PUT /v2/wallet/secret (FD_Demo_Token)", status, raw, json)
	write "FlightDeck demo: wallet-secret FD_Demo_Token created", !
	quit $$$OK
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

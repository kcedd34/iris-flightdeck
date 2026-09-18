/// /v1/session (FR-009 to FR-018, FR-012a). Identity is IRIS's: IRIS authenticates the request
/// with Password authentication before this code runs and keeps its own CSP session. This class
/// never sees, stores or returns a credential.
Class FlightDeck.API.Session [ Abstract ]
{

/// POST /v1/session. Reached only after IRIS accepted the credentials; any 401 is produced by IRIS
/// before dispatch (analysis U1).
ClassMethod Create() As %Status
{
	quit ..Respond(1)
}

/// GET /v1/session
ClassMethod Read() As %Status
{
	quit ..Respond(0)
}

/// DELETE /v1/session: ends the IRIS session.
ClassMethod Delete() As %Status
{
	do ..EndIrisSession()
	set %response.Status = "204 No Content"
	quit $$$OK
}

ClassMethod Respond(isSignIn As %Boolean) As %Status
{
	set session = ..Build(.error)
	if $isobject(error) {
		// A refused sign-in leaves no IRIS session behind (FR-012a, UC01 A2).
		do ..EndIrisSession()
		quit ##class(FlightDeck.API.Response).WriteError(error.status, error.code, error.message, error.raw, error.requires, error.detectedVersion)
	}
	quit ##class(FlightDeck.API.Response).WriteJSON(session)
}

/// "%Admin_Manage, %Admin_Operate and %Admin_Secure" from the privilege list.
ClassMethod PrivilegeList(requires As %DynamicArray) As %String
{
	set text = "", iter = requires.%GetIterator()
	while iter.%GetNext(, .requirement) {
		set name = $piece(requirement, ":", 1)
		set text = text _ $select(text="":"", 1:", ") _ name
	}
	quit text
}

/// Builds the Session body from /info (FR-012). On refusal returns "" and sets error.
ClassMethod Build(Output error As %DynamicObject) As %DynamicObject
{
	set error = ""
	// FR-012a: refuse only an instance without any SysAdmin API; IRIS 2026.1 (v1) runs in limited mode.
	if '##class(FlightDeck.Admin.Client).ApiPresent() {
		set error = {"status":403, "code":"UNSUPPORTED_VERSION", "message":(##class(FlightDeck.API.Response).#MSGNOAPI), "raw":"", "requires":"", "detectedVersion":($zversion)}
		quit ""
	}
	set sc = ##class(FlightDeck.Admin.Client).Call("GET", "/info", , , .status, .json, .raw)
	if $$$ISERR(sc) {
		set error = {"status":500, "code":"UPSTREAM_ERROR", "message":"The instance information could not be read.", "raw":($system.Status.GetErrorText(sc)), "requires":"", "detectedVersion":""}
		quit ""
	}
	if (status = 403) || (status = 404) {
		// The instance refused FlightDeck's one identity read. It is not a version problem: the API
		// answered. It is not always a missing privilege either — an account holding %Admin_Wallet
		// only is refused here while its own operations answer (verification/README.md) — so the
		// message states what happened and what to ask for, and lists the privileges FlightDeck uses.
		set requires = ##class(FlightDeck.Capability.Map).AllRequiredPrivileges()
		set message = ##class(FlightDeck.API.Response).#MSGNOINFO _ " FlightDeck uses these privileges across the portal: " _ ..PrivilegeList(requires) _ "."
		set error = {"status":403, "code":"NO_ADMIN_PRIVILEGE", "message":(message), "raw":(##class(FlightDeck.Admin.Client).ErrorText(json, raw)), "requires":(requires), "detectedVersion":""}
		quit ""
	}
	if (status '= 200) || '$isobject(json) {
		set error = {"status":502, "code":"UPSTREAM_ERROR", "message":"The instance information could not be read.", "raw":(raw), "requires":"", "detectedVersion":""}
		quit ""
	}
	set info = json.result
	set privileges = ##class(FlightDeck.Capability.Map).NormalizePrivileges(info.privileges)
	set entries = ##class(FlightDeck.Capability.Map).Build(privileges)
	set version = $zstrip($piece($piece(info.serverVersion, ") ", 2), " (", 1), "<>W")
	set edition = ..Edition(privileges)
	set session = {
		"username": (info.username),
		"instance": {
			"product": (info.product),
			"version": (version),
			"serverVersion": (info.serverVersion),
			"apiVersion": (+info.apiVersion),
			"edition": (edition),
			"namespace": ($namespace),
			"dialect": (##class(FlightDeck.Admin.Client).Dialect())
		},
		"authPath": "in_process",
		"privileges": (privileges),
		"capabilitySummary": (##class(FlightDeck.Capability.Map).Summary(entries))
	}
	quit session
}

/// "Community" when the license reports a Community platform, "" when not, null when the user
/// cannot read license information (GET /v2/license/key requires %Admin_Manage:U). Only the
/// platform name is used; the license key itself is never returned.
ClassMethod Edition(privileges As %DynamicObject) As %String
{
	set manage = privileges.%Get("%Admin_Manage")
	if '$isobject(manage) || 'manage.use quit ""
	set key = ##class(FlightDeck.Admin.Client).Get("/v2/license/key", , .status, .raw)
	if (status '= 200) || '$isobject(key) quit ""
	quit $select(key.Platform["Community":"Community", 1:"")
}

ClassMethod EndIrisSession()
{
	if $data(%session)#2, $isobject(%session) {
		do %session.Logout(1)
		set %session.EndSession = 1
	}
}

}

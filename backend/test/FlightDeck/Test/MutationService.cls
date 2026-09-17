/// Preview and apply (feature 002 T038, research R4): no change sends nothing, a changed server state
/// is never overwritten, confirmations are enforced, rejections are classified, trail records are
/// produced.
Class FlightDeck.Test.MutationService Extends FlightDeck.Test.MutationSupport
{

Method TestNoChangeSendsNothing()
{
	set preview = ..Preview("PUT /v2/web-app", ..#APP, {"Enabled":true})
	do $$$AssertTrue(preview.noChange)
	set result = ..Apply("PUT /v2/web-app", ..#APP, {"Enabled":true}, preview.fingerprint, , , .status)
	do $$$AssertEquals(status, 422)
	do $$$AssertEquals(result.error.code, "NO_CHANGE")
	do $$$AssertEquals(result.error.message, "Nothing to apply. The proposed state matches the current one.")
}

Method TestStateChangedIsNeverOverwritten()
{
	set timeout = ..Official(..#APP).Timeout + 1
	set description = ..Official(..#APP).Description
	set preview = ..Preview("PUT /v2/web-app", ..#APP, {"Description":"from the dry-run"})
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/web-app", {"name":(..#APP)}, {"Timeout":(timeout)})
	set result = ..Apply("PUT /v2/web-app", ..#APP, {"Description":"from the dry-run"}, preview.fingerprint, , , .status)
	do $$$AssertEquals(status, 409)
	do $$$AssertEquals(result.error.code, "STATE_CHANGED")
	do $$$AssertTrue($isobject(result.preview) && (result.preview.fingerprint '= preview.fingerprint), "a fresh preview comes back")
	set official = ..Official(..#APP)
	do $$$AssertEquals(official.Description, description, "nothing written")
	do $$$AssertEquals(official.Timeout, timeout, "the external change stays")
}

Method TestAppliedSendsOnlyChangedFieldsAndRecordsTrail()
{
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/web-app", {"name":(..#APP)}, {"Timeout":777})
	do ##class(FlightDeck.Domain.LinkCache).Set("role-map", {"marker":true})
	set preview = ..Preview("PUT /v2/web-app", ..#APP, {"Description":"applied by test", "Timeout":777})
	set result = ..Apply("PUT /v2/web-app", ..#APP, {"Description":"applied by test", "Timeout":777}, preview.fingerprint, , , .status)
	do $$$AssertEquals(status, 200, result.%ToJSON())
	do $$$AssertEquals(result.trail.result, "Applied")
	do $$$AssertEquals(result.trail.target, ..#APP)
	do $$$AssertEquals(result.result.Description, "applied by test", "result is the re-read official object")
	set changed = ""
	set iter = result.trail.rows.%GetIterator()
	while iter.%GetNext(, .row) { set:row.changed changed = changed _ row.field _ "," }
	do $$$AssertEquals(changed, "Description,", "Timeout already 777: only Description changed")
	do $$$AssertNotTrue(##class(FlightDeck.Domain.LinkCache).Get("role-map"), "links invalidated after Applied")
}

Method TestConfirmationEnforcedByServer()
{
	set preview = ..Preview("PUT /v2/web-app", ..#APP, {"Enabled":false})
	set result = ..Apply("PUT /v2/web-app", ..#APP, {"Enabled":false}, preview.fingerprint, "wrong", , .status)
	do $$$AssertEquals(status, 422)
	do $$$AssertEquals(result.error.code, "CONFIRMATION_REQUIRED")
	do $$$AssertEquals(..Official(..#APP).Enabled, 1, "not written")
	set system = ..Preview("DELETE /v2/web-app", "/csp/documatic")
	set result = ..Apply("DELETE /v2/web-app", "/csp/documatic", , system.fingerprint, "/csp/documatic", 0, .status)
	do $$$AssertEquals(status, 422, "maximum grade needs the acknowledgement")
	do $$$AssertTrue($isobject(..Official("/csp/documatic")), "system application untouched")
}

Method TestValidationRejectionIsClassified()
{
	set preview = ..Preview("PUT /v2/web-app", ..#APP, {"Timeout":"abc"})
	set result = ..Apply("PUT /v2/web-app", ..#APP, {"Timeout":"abc"}, preview.fingerprint, , , .status)
	do $$$AssertEquals(status, 502)
	do $$$AssertEquals(result.error.code, "UPSTREAM_REJECTED")
	do $$$AssertTrue(result.validation, "HTTP 500 with #7207 is an input rejection (research R2)")
	do $$$AssertTrue(result.error.message [ "#7207", result.error.message)
	do $$$AssertEquals(result.trail.result, "Failed")
	do $$$AssertEquals(result.trail.status, 500)
}

Method TestDeleteApplied()
{
	set name = "/csp/fdt-mutation-delete"
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/web-app", {"name":(name)}, {"NameSpace":"USER"})
	set preview = ..Preview("DELETE /v2/web-app", name)
	do $$$AssertEquals(preview.kind, "delete")
	set result = ..Apply("DELETE /v2/web-app", name, , preview.fingerprint, name, , .status)
	do $$$AssertEquals(status, 200, result.%ToJSON())
	do ##class(FlightDeck.Admin.Client).Get("/v2/web-app", {"name":(name)}, .after)
	do $$$AssertEquals(after, 404)
}

}

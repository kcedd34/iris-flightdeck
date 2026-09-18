/// Action-kind mutations (feature 003 T007, T008): an official operation that changes state through
/// a verb with parameters and no editable object still shows a before-and-after diff, grades,
/// refuses a stale fingerprint, and reports no change when the action would change nothing.
/// <p>The descriptor is built here rather than shipped, so the machinery is tested independently of
/// the descriptors the domains declare. The subject is a real official operation on a scratch table.
Class FlightDeck.Test.MutationAction Extends %UnitTest.TestCase
{

Parameter ROLE = "FDT_ActionRole";

Parameter TABLE = "FDTAction.T";

Method OnBeforeAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/security/role", {"name":(..#ROLE)}, {"Description":"FlightDeck test: action-kind mutations"}, .status)
	set rs = ##class(%SQL.Statement).%ExecDirect(, "CREATE TABLE "_..#TABLE_" (id INT)")
	quit $$$OK
}

/// %UnitTest runs methods in alphabetical order, so each test sets its own baseline instead of
/// inheriting the previous one's state.
Method OnBeforeOneTest(testname As %String) As %Status
{
	do ..Revoke()
	if testname = "TestRevokeIsReinforcedAndStaleFingerprintIsRefused" do ..Grant()
	quit $$$OK
}

ClassMethod Grant()
{
	do ##class(FlightDeck.Admin.Client).Call("POST", "/v2/security/sql-privilege/grant", {"namespace":($namespace), "grantee":(..#ROLE), "type":"TABLE", "object":(..#TABLE), "action":"SELECT"}, , .status)
}

ClassMethod Revoke()
{
	do ##class(FlightDeck.Admin.Client).Call("POST", "/v2/security/sql-privilege/revoke", {"namespace":($namespace), "grantee":(..#ROLE), "type":"TABLE", "object":(..#TABLE), "action":"SELECT"}, , .status)
}

Method OnAfterAllTests() As %Status
{
	do ##class(FlightDeck.Admin.Client).Call("POST", "/v2/security/sql-privilege/revoke", {"namespace":($namespace), "grantee":(..#ROLE), "type":"TABLE", "object":(..#TABLE), "action":"SELECT"}, , .status)
	do ##class(%SQL.Statement).%ExecDirect(, "DROP TABLE "_..#TABLE)
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/role", {"name":(..#ROLE)}, , .status)
	quit $$$OK
}

/// grant and revoke, shaped as the feature's descriptors will be.
ClassMethod Descriptor(effect As %String) As %DynamicObject
{
	set verb = $select(effect="add":"grant", 1:"revoke")
	quit {
		"kind": "action",
		"params": ["namespace", "grantee", "type", "object", "action"],
		"options": ["withGrant"],
		"readOperation": "GET /v2/security/sql-privileges",
		"readParams": {"grantee":"{grantee}", "namespace":"{namespace}", "maxRows":"1000"},
		"rowKey": [ {"field":"Type", "value":"{type}"}, {"field":"Object|Name", "value":"{object}"}, {"field":"Action|Privilege", "value":"{action}"} ],
		"rowLabel": "{action} on {object}",
		"effect": (effect),
		"target": ("{action} on {object} for {grantee}"),
		"secretFields": [],
		"grade": [ {"when": {"op":"equals", "path":"kind", "value":"action"}, "grade": ($select(effect="add":"simple", 1:"reinforced"))} ],
		"operationSuffix": (verb)
	}
}

ClassMethod Request(effect As %String) As %DynamicObject
{
	quit {
		"operationId": ("POST /v2/security/sql-privilege/"_$select(effect="add":"grant", 1:"revoke")),
		"params": {"namespace":($namespace), "grantee":(..#ROLE), "type":"TABLE", "object":(..#TABLE), "action":"SELECT"},
		"options": {}
	}
}

/// Preview through the shipped descriptor and the real service, not a local copy.
ClassMethod Preview(effect As %String, Output ctx As %DynamicObject) As %DynamicObject
{
	quit ##class(FlightDeck.Mutation.Service).DoPreview(..Request(effect), .status)
}

Method TestGrantShowsTheRowBeforeAndAfter()
{
	set preview = ..Preview("add", .ctx)
	do $$$AssertEquals(preview.kind, "action")
	do $$$AssertEquals(preview.rows.%Size(), 1, "one affected row")
	set row = preview.rows.%Get(0)
	do $$$AssertEquals(row.current, "not granted")
	do $$$AssertEquals(row.commanded, "granted")
	do $$$AssertTrue(row.changed, "the row changes")
	do $$$AssertNotTrue(preview.noChange, "an absent privilege is a change")
	do $$$AssertEquals(preview.target, "SELECT on "_..#TABLE_" for "_..#ROLE)
	do $$$AssertEquals(preview.grade, "simple")
}

Method TestApplyGrantsAndThenReportsNoChange()
{
	set descriptor = ..Descriptor("add")
	set request = ..Request("add")
	set preview = ..Preview("add", .ctx)
	set request.fingerprint = preview.fingerprint
	set response = ##class(FlightDeck.Mutation.Service).DoApply(request, .status)
	do $$$AssertEquals(status, 200, "the grant is applied")
	do $$$AssertEquals(response.trail.result, "Applied")
	do $$$AssertEquals(response.trail.kind, "action")
	// The official listing now reports it, so granting again would change nothing.
	set second = ..Preview("add", .ctx2)
	do $$$AssertTrue(second.noChange, "granting an existing privilege changes nothing")
	do $$$AssertEquals(second.rows.%Get(0).current, "granted (Direct)", "the row shows the provenance the API reports")
}

Method TestRevokeIsReinforcedAndStaleFingerprintIsRefused()
{
	set preview = ..Preview("remove", .ctx)
	do $$$AssertEquals(preview.grade, "reinforced", "a revocation asks for the typed target")
	do $$$AssertEquals(preview.confirmText, preview.target)
	set request = ..Request("remove")
	set request.fingerprint = "stale-fingerprint"
	set request.confirmation = preview.target
	set response = ##class(FlightDeck.Mutation.Service).DoApply(request, .status)
	do $$$AssertEquals(status, 409, "a fingerprint that does not match the re-read state is refused")
	do $$$AssertEquals(response.error.code, "STATE_CHANGED")
	// With the right fingerprint and confirmation it applies.
	set request.fingerprint = preview.fingerprint
	set response = ##class(FlightDeck.Mutation.Service).DoApply(request, .status)
	do $$$AssertEquals(status, 200, "the revocation is applied")
	do $$$AssertEquals(response.trail.result, "Applied")
	set after = ..Preview("remove", .ctx3)
	do $$$AssertTrue(after.noChange, "revoking an absent privilege changes nothing")
}

/// A missing declared parameter never reaches the official API.
Method TestMissingParameterIsRefused()
{
	set request = ..Request("add")
	do request.params.%Remove("object")
	set ctx = ##class(FlightDeck.Mutation.Action).Context(request, ..Descriptor("add"), .failure)
	do $$$AssertTrue($isobject(failure), "a missing parameter fails")
	do $$$AssertEquals(failure.code, "MISSING_KEY")
}

}

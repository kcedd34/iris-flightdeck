/// Dialect selection and limited mode (FR-012a, Constitution I and III dialect notes). Runs on both
/// dialects; expectations follow the apiVersion the instance's own /info reports.
Class FlightDeck.Test.Dialect Extends %UnitTest.TestCase
{

/// apiVersion straight from the instance's dispatcher, bypassing the selection under test.
Method InstanceApiVersion() As %Integer
{
	for dispatcher = "%Api.Admin", "Api.Admin" {
		continue:'##class(FlightDeck.Admin.Dialect).ClassExistsInSys(dispatcher)
		do ##class(FlightDeck.Admin.Client).Dispatch(dispatcher, "/info", "GET", "", "", .status, .json)
		if status = 200, $isobject(json) return +json.result.apiVersion
	}
	quit 0
}

Method OnBeforeOneTest(testname As %String) As %Status
{
	do ##class(FlightDeck.Admin.Dialect).Reset()
	quit $$$OK
}

Method TestDialectFollowsInstanceInfo()
{
	set version = ..InstanceApiVersion()
	set expected = $select(version>=2:"v2", version=1:"v1", 1:"none")
	do $$$AssertEquals(##class(FlightDeck.Admin.Client).Dialect(), expected, "apiVersion "_version)
	do $$$AssertEquals(##class(FlightDeck.Admin.Client).ApiPresent(), 1)
	do $$$AssertEquals(##class(FlightDeck.Admin.Client).Limited(), (expected = "v1"))
}

Method TestSelectedOncePerProcess()
{
	set first = ##class(FlightDeck.Admin.Dialect).Current()
	set ^||FlightDeck.Dialect = "sentinel"
	do $$$AssertEquals(##class(FlightDeck.Admin.Dialect).Current(), "sentinel", "the cached selection is reused, not re-detected")
	do ##class(FlightDeck.Admin.Dialect).Reset()
	do $$$AssertEquals(##class(FlightDeck.Admin.Dialect).Current(), first)
}

Method TestCapabilityMapAvailability()
{
	set privileges = ##class(FlightDeck.Capability.Map).NormalizePrivileges(##class(FlightDeck.Admin.Client).Get("/info").privileges)
	set entries = ##class(FlightDeck.Capability.Map).Build(privileges)
	set summary = ##class(FlightDeck.Capability.Map).Summary(entries)
	do $$$AssertEquals(summary.total, 273)
	set byId = {}
	set iter = entries.%GetIterator()
	while iter.%GetNext(, .e) { do byId.%Set(e.operationId, e) }
	if ##class(FlightDeck.Admin.Client).Limited() {
		// 273 v2 operations. 62 are unavailable on this version and 11 are declined by policy on every
		// version: three of the storage writes that were merely absent here are now declined, which is
		// a different reason for the same disabled control and is counted apart (feature 004).
		do $$$AssertEquals(summary.unavailable, 62)
		do $$$AssertEquals(summary.declined, 11)
		set dbs = byId.%Get("GET /v2/databases")
		do $$$AssertNotTrue(dbs.available, "databases have no v1 route")
		do $$$AssertEquals(dbs.reason, ##class(FlightDeck.API.Response).#MSGVERSION)
		do $$$AssertEquals(dbs.requires.%ToJSON(), "[""%Admin_Manage:U"",""%Admin_Operate:U""]", "privilege still comes from the v2 spec")
		do $$$AssertTrue(byId.%Get("GET /v2/namespaces").available, "native namespace read is available")
		set write = byId.%Get("PUT /v2/namespace")
		do $$$AssertNotTrue(write.available, "namespace writes are never native")
		do $$$AssertTrue($extract(write.reason, 1, $length(##class(FlightDeck.API.Response).#MSGVERSION)) = ##class(FlightDeck.API.Response).#MSGVERSION, "reason starts with message 8")
		do $$$AssertTrue(write.reason [ "side effects FlightDeck does not control", write.reason)
		set journal = byId.%Get("GET /v2/journal/files")
		do $$$AssertNotTrue(journal.available)
		do $$$AssertTrue(journal.reason [ "authorization decision that belongs to IRIS", journal.reason)
		do $$$AssertTrue(byId.%Get("POST /v2/task/suspend").available, "translated operation is available")
		do $$$AssertTrue(byId.%Get("GET /v2/security/roles").available, "same-shape operation is available")
	} else {
		do $$$AssertEquals(summary.unavailable, 0)
		do $$$AssertTrue(byId.%Get("GET /v2/namespaces").available)
	}
}

Method TestUnavailableOperationNeverReachesIris()
{
	set sc = ##class(FlightDeck.Admin.Client).Call("GET", "/v2/databases", , , .status, .json, .raw)
	do $$$AssertStatusOK(sc)
	if ##class(FlightDeck.Admin.Client).Limited() {
		do $$$AssertEquals(status, 501)
		do $$$AssertEquals(json.status.errors.%Get(0).code, "FLIGHTDECK_UNAVAILABLE")
		do $$$AssertEquals(json.status.errors.%Get(0).error, ##class(FlightDeck.API.Response).#MSGVERSION)
	} else {
		do $$$AssertEquals(status, 200)
	}
}

Method TestSessionReportsDialect()
{
	set session = ##class(FlightDeck.API.Session).Build(.error)
	do $$$AssertNotTrue($isobject(error), "signed in, not refused: "_$select($isobject(error):error.%ToJSON(), 1:""))
	quit:'$isobject(session)
	// dialect and apiVersion are diagnostics; limited mode is carried only by the capability map.
	do $$$AssertEquals(session.instance.dialect, ##class(FlightDeck.Admin.Client).Dialect())
	do $$$AssertEquals(session.instance.apiVersion, ..InstanceApiVersion())
	do $$$AssertNotTrue(session.instance.%IsDefined("limited"), "no limited flag in the session")
	// Unavailable counts what this instance does not offer. Operations FlightDeck declines to offer
	// on any version are counted separately, so the equivalence with limited mode still holds
	// (feature 003 capability policy).
	do $$$AssertEquals(session.capabilitySummary.unavailable > 0, ##class(FlightDeck.Admin.Client).Limited(), "unavailable operations exist exactly in limited mode")
	do $$$AssertTrue(session.capabilitySummary.declined > 0, "the policy declines at least one operation on every version")
}

Method TestPaletteReportsUnavailableGroups()
{
	set out = ##class(FlightDeck.Palette.Search).Run("fd")
	set unavailable = 0, reasons = 1
	set iter = out.groups.%GetIterator()
	while iter.%GetNext(, .g) {
		continue:g.state'="unavailable"
		set unavailable = unavailable + 1
		set:($extract(g.reason, 1, $length(##class(FlightDeck.API.Response).#MSGVERSION))'=##class(FlightDeck.API.Response).#MSGVERSION) reasons = 0
	}
	if ##class(FlightDeck.Admin.Client).Limited() {
		do $$$AssertTrue(unavailable > 0, unavailable_" unavailable groups on v1")
		do $$$AssertTrue(reasons, "every unavailable group starts with the version message")
		do $$$AssertNotTrue(out.degraded && (out.reason = ""), "unavailable groups alone do not degrade the search")
	} else {
		do $$$AssertEquals(unavailable, 0)
	}
}

}

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
		// 273 v2 operations, 201 with a v1 route (173 same shape + 28 translated): 72 unavailable.
		do $$$AssertEquals(summary.unavailable, 72)
		set ns = byId.%Get("GET /v2/namespaces")
		do $$$AssertNotTrue(ns.available, "namespaces have no v1 route")
		do $$$AssertEquals(ns.reason, ##class(FlightDeck.API.Response).#MSGVERSION)
		do $$$AssertEquals(ns.requires.%Get(0), "%Admin_Manage:U", "privilege still comes from the v2 spec")
		do $$$AssertTrue(byId.%Get("POST /v2/task/suspend").available, "translated operation is available")
		do $$$AssertTrue(byId.%Get("GET /v2/security/roles").available, "same-shape operation is available")
	} else {
		do $$$AssertEquals(summary.unavailable, 0)
		do $$$AssertTrue(byId.%Get("GET /v2/namespaces").available)
	}
}

Method TestUnavailableOperationNeverReachesIris()
{
	set sc = ##class(FlightDeck.Admin.Client).Call("GET", "/v2/namespaces", , , .status, .json, .raw)
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
	do $$$AssertEquals(session.instance.dialect, ##class(FlightDeck.Admin.Client).Dialect())
	do $$$AssertEquals(session.instance.limited, ##class(FlightDeck.Admin.Client).Limited())
	do $$$AssertEquals(session.instance.apiVersion, ..InstanceApiVersion())
	do $$$AssertEquals(session.instance.%GetTypeOf("limited"), "boolean")
}

Method TestPaletteReportsUnavailableGroups()
{
	set out = ##class(FlightDeck.Palette.Search).Run("fd")
	set unavailable = 0, reasons = 1
	set iter = out.groups.%GetIterator()
	while iter.%GetNext(, .g) {
		continue:g.state'="unavailable"
		set unavailable = unavailable + 1
		set:(g.reason'=##class(FlightDeck.API.Response).#MSGVERSION) reasons = 0
	}
	if ##class(FlightDeck.Admin.Client).Limited() {
		do $$$AssertTrue(unavailable > 0, unavailable_" unavailable groups on v1")
		do $$$AssertTrue(reasons, "every unavailable group carries the version message")
		do $$$AssertNotTrue(out.degraded && (out.reason = ""), "unavailable groups alone do not degrade the search")
	} else {
		do $$$AssertEquals(unavailable, 0)
	}
}

}

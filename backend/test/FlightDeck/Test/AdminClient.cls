Class FlightDeck.Test.AdminClient Extends %UnitTest.TestCase
{

Method TestInfoReportsApiV2()
{
	set sc = ##class(FlightDeck.Admin.Client).Call("GET", "/info", , , .status, .json, .raw)
	do $$$AssertStatusOK(sc)
	do $$$AssertEquals(status, 200)
	do $$$AssertTrue($isobject(json) && (json.result.apiVersion >= 2), "apiVersion >= 2")
}

Method TestCallerStateIsRestored()
{
	set ns = $namespace
	set %response = ##class(%CSP.Response).%New()
	set before = %response
	set sc = ##class(FlightDeck.Admin.Client).Call("GET", "/v2/security/roles", {"maxRows":1}, , .status)
	do $$$AssertStatusOK(sc)
	do $$$AssertEquals($namespace, ns, "namespace restored")
	do $$$AssertTrue(%response = before, "%response object restored")
	kill %response
}

Method TestNamespaceSwitchReachesSysQueries()
{
	// /v2/processes fails with ERROR #5660 unless the handler runs in %SYS (research R4).
	set sc = ##class(FlightDeck.Admin.Client).Call("GET", "/v2/processes", {"maxRows":1}, , .status, .json, .raw)
	do $$$AssertStatusOK(sc)
	do $$$AssertEquals(status, 200, raw)
}

Method TestApiErrorIsPassedThrough()
{
	set sc = ##class(FlightDeck.Admin.Client).Call("GET", "/v2/security/role", {"name":"FD_Test_Does_Not_Exist"}, , .status, .json, .raw)
	do $$$AssertStatusOK(sc)
	do $$$AssertEquals(status, 404)
	do $$$AssertTrue(##class(FlightDeck.Admin.Client).ErrorText(json, raw) [ "does not exist")
}

}

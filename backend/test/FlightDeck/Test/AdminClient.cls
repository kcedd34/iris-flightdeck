Class FlightDeck.Test.AdminClient Extends %UnitTest.TestCase
{

/// /info answers through the client under the caller's identity (the version it reports is the
/// dialect layer's concern, tested in FlightDeck.Test.Dialect).
Method TestInfoReportsCallerIdentity()
{
	set sc = ##class(FlightDeck.Admin.Client).Call("GET", "/info", , , .status, .json, .raw)
	do $$$AssertStatusOK(sc)
	do $$$AssertEquals(status, 200)
	do $$$AssertTrue($isobject(json) && $isobject(json.result), raw)
	do $$$AssertEquals(json.result.username, $username)
	do $$$AssertTrue($isobject(json.result.privileges), "privileges reported")
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

Method TestPostWithoutBodySendsJson()
{
	// /v2/task/suspend declares an optional body and returns 415 without a JSON content type.
	do $$$AssertStatusOK(##class(FlightDeck.Install.Demo).Tasks())
	set tasks = ##class(FlightDeck.Admin.Client).Get("/v2/tasks", {"filter":"FD Demo daily", "maxRows":5}, .status)
	set id = tasks.%Get(0).Id
	set sc = ##class(FlightDeck.Admin.Client).Call("POST", "/v2/task/suspend", {"id":(id)}, , .status, .json, .raw)
	do $$$AssertStatusOK(sc)
	do $$$AssertEquals(status, 200, raw)
	set info = ##class(FlightDeck.Admin.Client).Get("/v2/task/info", {"id":(id)}, .status)
	do $$$AssertTrue(info.Suspended, "task is suspended (effect, not only HTTP 200)")
	do ##class(FlightDeck.Admin.Client).Call("POST", "/v2/task/resume", {"id":(id)}, , .status)
	set info = ##class(FlightDeck.Admin.Client).Get("/v2/task/info", {"id":(id)}, .status)
	do $$$AssertNotTrue(info.Suspended, "task resumed")
}

}

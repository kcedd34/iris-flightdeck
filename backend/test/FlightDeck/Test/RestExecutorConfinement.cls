/// REST test executor confinement (feature 002 T060, RN-FD-08, SC-009): only paths of this instance,
/// no credential headers, only enabled REST services.
Class FlightDeck.Test.RestExecutorConfinement Extends %UnitTest.TestCase
{

Method TestHostileTargetsRefused()
{
	for path = "http://example.com/", "https://example.com/api", "//example.com/x", "/a/../../b", "/%2e%2e/", "/%2E%2e/x", "/api/%252e%252e/x", "\\host\share", "/api\x", "api/no-slash", "/api/x://y", "", "/"_$char(0)_"x", "/api/"_$char(10)_"x" {
		set failure = ##class(FlightDeck.Rest.Executor).Validate({"method":"GET", "path":(path)})
		do $$$AssertTrue($isobject(failure) && (failure.code = "TARGET_OUTSIDE_INSTANCE"), "refused: "_$zconvert(path, "O", "JSON"))
	}
	for path = "/api/flightdeck/v1/openapi.json", "/api/monitor/metrics?x=1", "/api/mgmnt/" {
		do $$$AssertNotTrue($isobject(##class(FlightDeck.Rest.Executor).Validate({"method":"GET", "path":(path)})), "allowed: "_path)
	}
}

Method TestCredentialAndHostHeadersRefused()
{
	for header = "Authorization", "cookie", "Proxy-Authorization", "Host" {
		set request = {"method":"GET", "path":"/api/monitor/metrics", "headers":{}}
		do request.headers.%Set(header, "x")
		set failure = ##class(FlightDeck.Rest.Executor).Validate(request)
		do $$$AssertEquals($select($isobject(failure):failure.code, 1:""), "CREDENTIAL_HEADER", header)
	}
	do $$$AssertEquals(##class(FlightDeck.Rest.Executor).Validate({"method":"TRACE", "path":"/api/monitor/metrics"}).code, "BAD_REQUEST")
}

Method TestOnlyEnabledRestServicesRun()
{
	do ##class(FlightDeck.Rest.Executor).Run({"method":"GET", "path":"/api/iam/v1/x"}, .failure)
	do $$$AssertEquals(failure.code, "APPLICATION_DISABLED", "/api/iam is disabled on the default image")
	do ##class(FlightDeck.Rest.Executor).Run({"method":"GET", "path":"/csp/sys/UtilHome.csp"}, .failure)
	do $$$AssertEquals(failure.code, "NOT_A_REST_SERVICE")
	do ##class(FlightDeck.Rest.Executor).Run({"method":"GET", "path":"/fdt/nothing/here"}, .failure)
	do $$$AssertEquals(failure.code, "NO_WEB_APPLICATION")
}

Method TestRunsInsideTheInstance()
{
	set result = ##class(FlightDeck.Rest.Executor).Run({"method":"GET", "path":"/api/flightdeck/v1/openapi.json", "headers":{"X-FlightDeck-Tab":"unit"}}, .failure)
	do $$$AssertNotTrue($isobject(failure))
	do $$$AssertEquals(result.status, 200)
	do $$$AssertEquals(result.resolved.webApplication, "/api/flightdeck")
	do $$$AssertTrue(result.body [ """openapi""", "the served OpenAPI document")
	do $$$AssertTrue(result.elapsedMs >= 0)
}

}

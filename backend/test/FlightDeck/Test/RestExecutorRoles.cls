/// Roles of test requests (feature 002 T061), the regression test for spike T-EXEC-1
/// (verification/rest-executor-spike-2026.2.md): roles are kept or cleared to login roles, never
/// raised; the divergence for applications that grant roles is reported; $ROLES is restored.
/// <p>The test process adds FlightDeck_Runtime to its own roles to reproduce a FlightDeck request
/// (the web application adds it through MatchRoles). Tests may set $ROLES; FlightDeck code may not.
Class FlightDeck.Test.RestExecutorRoles Extends %UnitTest.TestCase
{

Method Run(path As %String, Output before As %String, Output after As %String) As %DynamicObject
{
	new $roles
	set $roles = "FlightDeck_Runtime"
	set before = $roles
	set result = ##class(FlightDeck.Rest.Executor).Run({"method":"GET", "path":(path), "headers":{"X-FlightDeck-Tab":"unit"}}, .failure)
	set after = $roles
	quit $select($isobject(failure):failure, 1:result)
}

Method TestFlightDeckApiKeepsCurrentRoles()
{
	set result = ..Run("/api/flightdeck/v1/openapi.json", .before, .after)
	do $$$AssertEquals(result.rolesMode, "current-kept", "FlightDeck_Runtime is exactly what the application grants")
	do $$$AssertEquals(result.grantsNotApplied.%Size(), 0)
	do $$$AssertEquals(result.status, 200)
	do $$$AssertEquals(after, before, "$ROLES restored")
}

Method TestEscalatingApplicationRunsWithLoginRolesAndSaysSo()
{
	set result = ..Run("/api/monitor/metrics", .before, .after)
	do $$$AssertEquals(result.rolesMode, "login-only", "FlightDeck_Runtime is not a grant of /api/monitor")
	do $$$AssertEquals(result.grantsNotApplied.%ToJSON(), "[""%DB_IRISSYS""]")
	do $$$AssertEquals(after, before, "$ROLES restored")
}

Method TestProtectAsStatusMapsTo403()
{
	set frame = ##class(FlightDeck.Rest.Executor).DispatchFrame("FlightDeck.Test.Probe.ProtectInHandler", "USER", "/protected", "GET", 1)
	do $$$AssertTrue(frame.protect, "an error status carrying <PROTECT> is a refusal, not HTTP 200")
	do $$$AssertTrue(frame.message [ "cannot read", frame.message)
}

Method TestGrantsAndMinus()
{
	set grants = ##class(FlightDeck.Rest.Executor).Grants([{"MatchRole":"", "TargetRoles":["A","B"]}, {"MatchRole":"%Developer", "TargetRoles":["C"]}, {"MatchRole":"%Nope", "TargetRoles":["D"]}], "%Developer,%Operator")
	do $$$AssertEquals(grants, "A,B,C")
	do $$$AssertEquals(##class(FlightDeck.Rest.Executor).Minus("A,B,C", "B"), "A,C")
}

}

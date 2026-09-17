/// Server-side self-protection (feature 002 T040, Constitution VII, research R7).
Class FlightDeck.Test.SelfProtection Extends FlightDeck.Test.MutationSupport
{

Method TestBlockedChangesToFlightDeckApplications()
{
	set cases = [
		{"op":"PUT /v2/web-app", "name":"/api/flightdeck", "proposed":{"Enabled":false}},
		{"op":"PUT /v2/web-app", "name":"/api/flightdeck", "proposed":{"NameSpace":"%SYS"}},
		{"op":"PUT /v2/web-app", "name":"/api/flightdeck", "proposed":{"DispatchClass":"%Api.Admin"}},
		{"op":"PUT /v2/web-app", "name":"/api/flightdeck", "proposed":{"AutheEnabled":64}},
		{"op":"PUT /v2/web-app", "name":"/flightdeck", "proposed":{"AutheEnabled":32}},
		{"op":"PUT /v2/web-app", "name":"/api/flightdeck", "proposed":{"MatchRoles":[]}},
		{"op":"DELETE /v2/web-app", "name":"/flightdeck"}
	]
	set iter = cases.%GetIterator()
	while iter.%GetNext(, .case) {
		set proposed = $select(case.%IsDefined("proposed"):case.proposed, 1:"")
		set label = case.%ToJSON()
		set preview = ..Preview(case.op, case.name, proposed)
		do $$$AssertTrue($isobject(preview.blocked), "preview explains the block: "_label)
		set result = ..Apply(case.op, case.name, proposed, preview.fingerprint, case.name, 1, .status)
		do $$$AssertEquals(status, 403, label)
		do $$$AssertEquals(result.error.message, "This web application serves FlightDeck. Disabling it would lock you out.", label)
		do $$$AssertEquals(result.trail.result, "Blocked", label)
	}
	do $$$AssertEquals(..Official("/api/flightdeck").Enabled, 1)
	do $$$AssertEquals(..Official("/flightdeck").AutheEnabled, 64)
}

Method TestAllowedChangesToFlightDeckApplications()
{
	set preview = ..Preview("PUT /v2/web-app", "/api/flightdeck", {"AutheEnabled":96})
	do $$$AssertNotTrue($isobject(preview.blocked), "adding a method keeps the required bit")
	set preview = ..Preview("PUT /v2/web-app", "/api/flightdeck", {"Description":"FlightDeck API (test)"})
	do $$$AssertNotTrue($isobject(preview.blocked))
	do $$$AssertEquals(preview.grade, "reinforced")
}

Method TestIdentifiedByInstallerRecordNotByName()
{
	do $$$AssertNotTrue($isobject(..Preview("PUT /v2/web-app", ..#APP, {"Enabled":false}).blocked), "other applications are not protected")
	merge saved = ^FlightDeck.Install("applications")
	set ^FlightDeck.Install("applications", ..#APP) = {"name":(..#APP), "requiredAuthBits":32, "runtimeRole":"FlightDeck_Runtime"}.%ToJSON()
	set blocked = $isobject(..Preview("PUT /v2/web-app", ..#APP, {"Enabled":false}).blocked)
	kill ^FlightDeck.Install("applications")
	merge ^FlightDeck.Install("applications") = saved
	do $$$AssertTrue(blocked, "a recorded application is protected whatever its name")
}

Method TestRefusedOnReReadStateEvenWhenPreviewPassed()
{
	// The fingerprint from a preview of an allowed change cannot be reused to apply a blocked one.
	set allowed = ..Preview("PUT /v2/web-app", "/api/flightdeck", {"Description":"x"})
	set result = ..Apply("PUT /v2/web-app", "/api/flightdeck", {"Enabled":false}, allowed.fingerprint, "/api/flightdeck", 1, .status)
	do $$$AssertEquals(status, 403)
	do $$$AssertEquals(..Official("/api/flightdeck").Enabled, 1)
}

}

/// The last-administrator predicate (feature 003 spec FR-010 to FR-010c).
/// <p>This predicate fails by permitting, not by refusing, so the case that proves self-protection
/// exists is the **positive** one, and it runs against the real instance: the instance is narrowed
/// to a single counted administrator, the change that would remove that one is proposed, and the
/// server must refuse it. Everything touched is restored afterwards, whatever the outcome.
Class FlightDeck.Test.LastAdmin Extends %UnitTest.TestCase
{

/// Accounts disabled by the positive test, as {name: wasEnabled}, restored in OnAfterOneTest.
Property Suspended As %String;

Parameter KEEP = "_SYSTEM";

Method OnBeforeOneTest(testname As %String) As %Status
{
	kill %FlightDeckRoleDetail, %FlightDeckRoleOwners, %FlightDeckUserDetail
	set ..Suspended = ""
	quit $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
	do ..Restore()
	quit $$$OK
}

ClassMethod Holders(Output complete As %Boolean, Output unread As %DynamicArray) As %DynamicArray
{
	kill %FlightDeckRoleDetail, %FlightDeckRoleOwners, %FlightDeckUserDetail
	set unread = []
	quit ##class(FlightDeck.Mutation.LastAdmin).Holders({}, unread, .complete)
}

ClassMethod SetEnabled(name As %String, enabled As %Boolean) As %Integer
{
	do ##class(FlightDeck.Admin.Client).Call("PUT", "/v2/security/user", {"name":(name)}, {"Enabled":(''enabled)}, .status)
	quit status
}

/// Re-enables everything the positive test disabled, and says so if it could not.
Method Restore()
{
	quit:..Suspended=""
	set names = $listfromstring(..Suspended, ",")
	set ptr = 0
	while $listnext(names, ptr, name) {
		continue:name=""
		set status = ..SetEnabled(name, 1)
		do:status'=200 $$$AssertFailure("could not re-enable "_name_" (HTTP "_status_"): re-enable it before using this instance")
	}
	set ..Suspended = ""
}

/// THE POSITIVE CASE, against the real instance: with one administrator left, the change that would
/// remove it is refused by the server, and nothing is written.
Method TestLegitimateBlockOnTheRealInstance()
{
	set before = ..Holders(.complete)
	do $$$AssertTrue(complete, "the instance is readable, so the check runs in complete mode")
	do $$$AssertTrue(before.%Size() >= 2, "the instance starts with more than one administrator")
	// Narrow the instance to a single counted administrator by disabling the others.
	set suspended = ""
	set iter = before.%GetIterator()
	while iter.%GetNext(, .name) {
		continue:name=..#KEEP
		set status = ..SetEnabled(name, 0)
		do:status'=200 $$$AssertFailure("could not disable "_name_": HTTP "_status)
		set suspended = suspended _ $select(suspended="":"", 1:",") _ name
	}
	set ..Suspended = suspended
	set narrowed = ..Holders(.complete2)
	do $$$AssertTrue(complete2, "still complete after narrowing")
	do $$$AssertEquals(narrowed.%Size(), 1, "exactly one administrator remains: "_narrowed.%ToJSON())
	do $$$AssertEquals(narrowed.%Get(0), ..#KEEP)

	// The change that would remove the last one: disable it.
	set request = {"operationId":"PUT /v2/security/user", "keys":{"name":(..#KEEP)}, "proposed":{"Enabled":false}}
	set preview = ##class(FlightDeck.Mutation.Service).DoPreview(request, .status)
	do $$$AssertEquals(status, 200)
	do $$$AssertTrue($isobject(preview.blocked), "the preview is blocked")
	quit:'$isobject(preview.blocked)
	do $$$AssertTrue(preview.blocked.message [ "%Admin_Secure", "the reason names the privilege it counted")
	do $$$AssertTrue(preview.blocked.message [ "%All", "the reason names the role it counted")
	do $$$AssertTrue(preview.blocked.message [ "delegated", "the reason states what it did not count")

	// And by any path: apply is refused server-side, recorded as blocked, with the mode it used.
	set request.fingerprint = preview.fingerprint
	set request.confirmation = preview.confirmText
	set response = ##class(FlightDeck.Mutation.Service).DoApply(request, .applyStatus)
	do $$$AssertEquals(applyStatus, 403)
	do $$$AssertEquals(response.error.code, "SELF_PROTECTION")
	do $$$AssertEquals(response.trail.result, "Blocked")
	do $$$AssertEquals(response.trail.checkMode, "complete")
	do $$$AssertEquals(response.trail.checkResult, "would-remove-last")

	// Nothing was written: the last administrator is still enabled.
	set user = ##class(FlightDeck.Admin.Client).Get("/v2/security/user", {"name":(..#KEEP)}, .readStatus)
	do $$$AssertEquals(readStatus, 200)
	do $$$AssertTrue(''user.Enabled, "the last administrator is untouched")

	do ..Restore()
	set restored = ..Holders(.complete3)
	do $$$AssertEquals(restored.%Size(), before.%Size(), "every administrator is back")
}

/// Probe finding A: on an instance whose administrators hold %All, an ordinary change is not blocked.
Method TestAllOnlyAdministratorsAreCounted()
{
	set holders = ..Holders(.complete)
	set found = 0
	set iter = holders.%GetIterator()
	while iter.%GetNext(, .name) {
		set user = ##class(FlightDeck.Admin.Client).Get("/v2/security/user", {"name":(name)}, .status)
		continue:status'=200
		if ##class(FlightDeck.Domain.Predicate).ArrayHas(user.Roles, "%All") set found = 1
	}
	do $$$AssertTrue(found, "an account holding only %All is counted as an administrator")
	// Removing another administrator's privilege is therefore not the last one.
	set request = {"operationId":"PUT /v2/security/user", "keys":{"name":"Admin"}, "proposed":{"Roles":["%EnsRole_Administrator"]}}
	set preview = ##class(FlightDeck.Mutation.Service).DoPreview(request, .status)
	do $$$AssertEquals(status, 200)
	do $$$AssertNotTrue($isobject(preview.blocked), "not blocked while %All accounts remain")
}

/// The official "no limit" sentinel is not a date in the past. IRIS 2026.2 normalises it to an empty
/// string and IRIS 2026.1 returns 1840-12-31 literally; reading it as a date made every account look
/// expired, and the predicate saw no administrator at all (found on the 2026.1 matrix run).
Method TestNoExpirySentinelIsNotAnExpiry()
{
	do $$$AssertNotTrue(##class(FlightDeck.Domain.Facts).Expired(""), "an empty date is no limit")
	do $$$AssertNotTrue(##class(FlightDeck.Domain.Facts).Expired("1840-12-31"), "the sentinel is no limit")
	do $$$AssertNotTrue(##class(FlightDeck.Domain.Facts).Expired("1840-12-31 00:00:00"), "the sentinel with a time is no limit")
	do $$$AssertTrue(##class(FlightDeck.Domain.Facts).Expired("2020-01-01"), "a past date is an expiry")
	do $$$AssertNotTrue(##class(FlightDeck.Domain.Facts).Expired($zdate($horolog + 30, 3)), "a future date is not")
	// And the instance itself has administrators: the sentinel never empties the counted set.
	set holders = ..Holders(.complete)
	do $$$AssertTrue(holders.%Size() > 0, "the predicate sees this instance's administrators")
}

/// Probe P1: an expired account is still reported as enabled, and must not be counted.
Method TestExpiredAccountIsNotCounted()
{
	set name = "FDT_ExpiredAdmin"
	do ##class(FlightDeck.Admin.Client).Call("POST", "/v2/security/user", {"name":(name)}, {"Password":"Fd-Test-Pass-2026", "User":{"Enabled":true, "ChangePassword":false, "FullName":"FlightDeck test", "Roles":["%All"], "ExpirationDate":"2020-01-01", "AccountNeverExpires":false}}, .status)
	do $$$AssertEquals(status, 201, "the expired administrator was created")
	set user = ##class(FlightDeck.Admin.Client).Get("/v2/security/user", {"name":(name)}, .readStatus)
	do $$$AssertTrue(''user.Enabled, "the platform still reports it as enabled")
	set holders = ..Holders(.complete)
	do $$$AssertNotTrue(##class(FlightDeck.Domain.Predicate).ArrayHas(holders, name), "an expired account is not an administrator")
	do ##class(FlightDeck.Admin.Client).Call("DELETE", "/v2/security/user", {"name":(name)}, , .status)
}

/// The rule itself: baseline, incomplete view, and the affirmative block.
Method TestDecisionRule()
{
	set held = ##class(FlightDeck.Mutation.LastAdmin).Decide(3, 2, 1)
	do $$$AssertEquals(held.mode, "complete")
	do $$$AssertEquals(held.result, "held")
	set block = ##class(FlightDeck.Mutation.LastAdmin).Decide(1, 0, 1)
	do $$$AssertEquals(block.result, "would-remove-last")
	// An empty baseline is not a block: the predicate cannot see this instance's administrators.
	set baseline = ##class(FlightDeck.Mutation.LastAdmin).Decide(0, 0, 1)
	do $$$AssertEquals(baseline.mode, "partial")
	do $$$AssertEquals(baseline.result, "not-determined")
	do $$$AssertTrue(baseline.unread.%Get(0) [ "no administrator was visible", "it says what it could not see")
	// A refused or capped read never asserts, even when the set looks empty afterwards.
	set partial = ##class(FlightDeck.Mutation.LastAdmin).Decide(2, 0, 0, ["user Admin (403)"])
	do $$$AssertEquals(partial.mode, "partial")
	do $$$AssertEquals(partial.result, "not-determined")
}

}

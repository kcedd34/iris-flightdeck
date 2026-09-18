/// Policy-declared unavailability (feature 003 T006, spec FR-020): an operation FlightDeck declines
/// to offer reaches every consumer as available = false with its reason, through the mechanism that
/// already exists, and with no version check anywhere.
Class FlightDeck.Test.CapabilityPolicy Extends %UnitTest.TestCase
{

Parameter DECLINED = "PUT /v2/security/encryption/settings";

Parameter OFFERED = "GET /v2/security/encryption/settings";

Method TestDeclinedOperationsAreUnavailableWithTheirReason()
{
	set entry = ##class(FlightDeck.Capability.Map).CurrentEntry(..#DECLINED)
	do $$$AssertNotTrue(entry.available, "declined operation is not available")
	do $$$AssertTrue(entry.reason [ "FlightDeck does not change encryption settings", "reason states the decision")
	do $$$AssertTrue(entry.reason [ "System Administration > Encryption", "reason names the native path")
	do $$$AssertNotTrue(entry.reason [ "IRIS 2026", "the reason is policy, not version")
}

Method TestOfferedReadsStayAvailable()
{
	set entry = ##class(FlightDeck.Capability.Map).CurrentEntry(..#OFFERED)
	do $$$AssertTrue(entry.available, "the read of the same family is offered")
}

/// The mutation service refuses a declined operation before it reaches the official API.
Method TestMutationServiceRefusesDeclined()
{
	set response = ##class(FlightDeck.Mutation.Service).DoPreview({"operationId":(..#DECLINED), "keys":{}}, .status)
	do $$$AssertEquals(status, $select($isobject(##class(FlightDeck.Domain.Descriptor).Mutation(..#DECLINED)):501, 1:404), "declined: 501 when a descriptor exists, 404 when none does")
	do $$$AssertTrue($isobject(response.error), "an error envelope is returned")
}

/// Every declined entry carries both fields, so no screen can show a blank reason.
Method TestEveryEntryHasReasonAndNativePath()
{
	set iter = ##class(FlightDeck.Capability.Policy).Declined().%GetIterator()
	set count = 0
	while iter.%GetNext(.operationId, .entry) {
		set count = count + 1
		do $$$AssertTrue(entry.reason '= "", operationId_" has a reason")
		do $$$AssertTrue(entry.nativePath '= "", operationId_" names the native path")
		do $$$AssertTrue($isobject(##class(FlightDeck.Capability.Map).Operation(operationId)), operationId_" exists in the official specification")
	}
	do $$$AssertTrue(count > 0, "the policy table is not empty")
}

}

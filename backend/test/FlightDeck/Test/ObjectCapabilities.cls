/// Feature 004: wherever an official schema states a capability over an object, that field decides
/// the control, and the server refuses what the object refuses (RN-FD-34, spec FR-028, FR-029).
/// <p>Written as a rule, not as a list of endpoints: processes and locks are the two instances this
/// feature meets, and a third would need no new test shape.
Class FlightDeck.Test.ObjectCapabilities Extends %UnitTest.TestCase
{

Method TestARefusedCapabilityRefusesTheOperation()
{
	set cases = $listbuild(
		$listbuild("POST /v2/process/terminate", "canBeTerminated", "cannot be terminated"),
		$listbuild("POST /v2/process/suspend", "canBeSuspended", "cannot be suspended"),
		$listbuild("POST /v2/process/broadcast", "canReceiveBroadcast", "cannot receive a broadcast"),
		$listbuild("DELETE /v2/lock", "removable", "cannot be removed"))
	set ptr = 0
	while $listnext(cases, ptr, case) {
		set operationId = $list(case, 1), fact = $list(case, 2), text = $list(case, 3)
		set descriptor = ##class(FlightDeck.Domain.Descriptor).Mutation(operationId)
		do $$$AssertTrue($isobject(descriptor), operationId_" has a descriptor")
		set refused = {}
		do refused.%Set(fact, 0, "boolean")
		set message = ##class(FlightDeck.Mutation.Service).Refusal(descriptor, {"facts":(refused)})
		do $$$AssertTrue(message [ text, operationId_" refused: "_message)
		set allowed = {}
		do allowed.%Set(fact, 1, "boolean")
		do $$$AssertEquals(##class(FlightDeck.Mutation.Service).Refusal(descriptor, {"facts":(allowed)}), "", operationId_" allowed")
	}
}

Method TestAnUnknownCapabilityIsNotARefusal()
{
	// A fact FlightDeck could not read is not a refusal: the platform answers for itself rather than
	// being denied by the portal on a guess. This is why the rule is written as refusedWhen.
	set descriptor = ##class(FlightDeck.Domain.Descriptor).Mutation("POST /v2/process/terminate")
	do $$$AssertEquals(##class(FlightDeck.Mutation.Service).Refusal(descriptor, {"facts":{}}), "")
}

Method TestOwnSessionIsBlockedBeforeAnythingElse()
{
	set descriptor = ##class(FlightDeck.Domain.Descriptor).Mutation("POST /v2/process/terminate")
	set facts = {}
	do facts.%Set("canBeTerminated", 1, "boolean")
	set message = ##class(FlightDeck.Mutation.Service).Refusal(descriptor, {"facts":(facts), "isOwnSession":1})
	do $$$AssertTrue(message [ "your own session", "the session's own process is blocked: "_message)
}

Method TestTheListCarriesTheRefusalSoARowNeedsNoDetailRead()
{
	set facts = {}
	do facts.%Set("canBeTerminated", 0, "boolean")
	set reason = ##class(FlightDeck.API.Entities).ObjectRefusal("POST /v2/process/terminate", facts)
	do $$$AssertTrue(reason '= "", "the list row carries the reason: "_reason)
}

}

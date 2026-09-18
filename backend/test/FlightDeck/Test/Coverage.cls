/// Feature 004 SC-001: every operation of a shipped domain is reachable or declined, proven on the
/// instance as well as in the build (scripts/build/check-coverage.py).
Class FlightDeck.Test.Coverage Extends %UnitTest.TestCase
{

Method TestDeclinedOperationsAreUnavailableWithTheirReason()
{
	set declined = $listbuild("POST /v2/database-dir/truncate", "DELETE /v2/database", "DELETE /v2/namespace")
	set ptr = 0
	while $listnext(declined, ptr, operationId) {
		set reason = ##class(FlightDeck.Capability.Policy).Reason(operationId)
		do $$$AssertTrue(reason '= "", operationId_" is declined with a reason")
		// The asymmetry is explained: FlightDeck creates these, and says where deletion is done.
		do $$$AssertTrue((reason [ "creates") || (reason [ "grows"), operationId_" says what FlightDeck does do: "_reason)
		do $$$AssertTrue(reason [ "management portal", operationId_" names the native path")
		set entry = ##class(FlightDeck.Capability.Map).CurrentEntry(operationId)
		do $$$AssertNotTrue(entry.available, operationId_" is not available")
		do $$$AssertTrue(''entry.declined, operationId_" is declined, not merely absent")
	}
}

Method TestEveryDescriptorOperationIsInTheSpec()
{
	// A descriptor that names an operation the specification does not declare would be a privilege
	// FlightDeck invented; the capability map is the only source (Constitution III).
	set mutations = ##class(FlightDeck.Domain.Descriptor).Mutations()
	set iter = mutations.%GetIterator(), missing = ""
	while iter.%GetNext(.operationId) {
		set entry = ##class(FlightDeck.Capability.Map).CurrentEntry(operationId)
		if '$isobject(entry) set missing = missing _ " " _ operationId
	}
	do $$$AssertEquals(missing, "", "every descriptor operation is in the capability map:"_missing)
}

Method TestTheTwoDomainsAreFullyDeclared()
{
	set types = ##class(FlightDeck.Domain.Descriptor).EntityTypes()
	set iter = types.%GetIterator(), tasks = 0, system = 0
	while iter.%GetNext(.id, .type) {
		if type.domain = "tasks" set tasks = tasks + 1
		if type.domain = "system" set system = system + 1
	}
	do $$$AssertTrue(tasks >= 4, "the tasks domain declares its entity types: "_tasks)
	do $$$AssertTrue(system >= 18, "the system domain declares its entity types: "_system)
}

}

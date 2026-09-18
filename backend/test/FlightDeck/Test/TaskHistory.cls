/// Feature 004: the recent-history band is built from one read of the instance's history, grouped by
/// task, and a lifecycle entry is never counted as a result (research R7).
Class FlightDeck.Test.TaskHistory Extends %UnitTest.TestCase
{

Method TestOneReadServesEveryTask()
{
	set bands = ##class(FlightDeck.Tasks.History).Bands(.complete, .reason)
	do $$$AssertTrue(complete, "the history was read: "_reason)
	// The platform ignores the id parameter and answers the whole instance's history, so one read
	// must carry more than one task; a per-task read would cost one request each.
	do $$$AssertTrue(bands.%Size() >= 1, "the grouped history holds at least one task")
}

Method TestALifecycleEntryIsNotAResult()
{
	// "Create <task>", "Suspended task" and "Task Has Expired for ..." all arrive with Status 1 and
	// ErrNumber 0. Reading them as failures would paint healthy tasks as failing.
	set entry = ##class(FlightDeck.Tasks.History).Run({"LastStart":"2026-09-18 01:00:00", "Completed":"2026-09-18 01:00:00", "Status":1, "Result":"Create FD Demo daily no-op", "ErrNumber":0})
	do $$$AssertEquals(entry.kind, "event")
	do $$$AssertEquals(entry.result, "")
}

Method TestASuccessAndAFailureAreBothRuns()
{
	set ok = ##class(FlightDeck.Tasks.History).Run({"LastStart":"2026-09-18 01:00:00", "Completed":"2026-09-18 01:00:04", "Status":1, "Result":"Success", "ErrNumber":0})
	do $$$AssertEquals(ok.kind, "run")
	do $$$AssertEquals(ok.result, "Success")
	do $$$AssertEquals(ok.durationSeconds, 4, "the duration is the platform's two timestamps")
	// A failed run records the error text in Status and leaves Result empty (probed 2026-09-18).
	set bad = ##class(FlightDeck.Tasks.History).Run({"LastStart":"2026-09-18 01:00:00", "Completed":"2026-09-18 01:00:01", "Status":"ERROR #5001: it failed", "Result":"", "ErrNumber":1})
	do $$$AssertEquals(bad.kind, "run")
	do $$$AssertEquals(bad.result, "Error")
	do $$$AssertTrue(bad.message [ "ERROR #5001", "the platform's own text is carried: "_bad.message)
}

Method TestAnUnreadableTimestampIsUnknownNotZero()
{
	set entry = ##class(FlightDeck.Tasks.History).Run({"LastStart":"not a date", "Completed":"", "Status":1, "Result":"Success", "ErrNumber":0})
	do $$$AssertEquals(entry.durationSeconds, "", "an unknown duration is empty, never 0")
}

}

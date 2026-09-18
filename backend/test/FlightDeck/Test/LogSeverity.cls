/// Feature 005: the severity scale, and the rule that keeps it honest — `unknown` is a value, not a
/// gap to be filled, and no mapping reads the message text (spec FR-003a, FR-003b).
Class FlightDeck.Test.LogSeverity Extends %UnitTest.TestCase
{

Method TestUnknownIsOutsideTheOrdering()
{
	do $$$AssertEquals(##class(FlightDeck.Logs.Event).Rank("info"), 1)
	do $$$AssertEquals(##class(FlightDeck.Logs.Event).Rank("fatal"), 4)
	do $$$AssertEquals(##class(FlightDeck.Logs.Event).Rank("unknown"), "", "unknown has no place in the ordering")
}

Method TestMessagesMapThePlatformsOwnLevel()
{
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Messages).Severity(0), "info")
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Messages).Severity(1), "warning")
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Messages).Severity(2), "error")
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Messages).Severity(3), "fatal")
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Messages).Severity(""), "unknown")
}

/// The test that catches a future "clever" inference: a line whose text contains the word error, at
/// a level the platform called informational, is informational.
Method TestSeverityIsNeverReadFromTheText()
{
	set event = ##class(FlightDeck.Logs.Sources.Messages).Parse("messages", "id", "09/18/26-04:45:26:546 (1) 0 [Generic.Event] no errors found")
	do $$$AssertEquals(event.severity, "info", "the level decides, not the words: "_event.message)
	set fatal = ##class(FlightDeck.Logs.Sources.Messages).Parse("messages", "id", "09/18/26-04:45:26:546 (1) 3 [Generic.Event] everything is fine")
	do $$$AssertEquals(fatal.severity, "fatal", "and the other way round too")
}

Method TestAnUnknownSeverityIsNotFilteredOutBySilence()
{
	set unknown = ##class(FlightDeck.Logs.Event).New("journal", "1", "2026-09-18 12:00:00", "unknown", "SET ^Global")
	// A minimum severity cannot rank an unknown, so it is kept unless the caller excludes it.
	do $$$AssertTrue(##class(FlightDeck.Logs.Stream).Matches(unknown, {"minSeverity":"error"}), "kept by default")
	do $$$AssertNotTrue(##class(FlightDeck.Logs.Stream).Matches(unknown, {"minSeverity":"error", "includeUnknown":"false"}), "excluded only when asked")
}

}

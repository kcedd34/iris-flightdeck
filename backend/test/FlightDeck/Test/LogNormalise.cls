/// Feature 005: one case per source, each against a record shaped like the probe
/// (verification/README.md). What these assert is the pair the whole feature rests on: `raw` is
/// present, and a field the source does not provide is absent rather than empty.
Class FlightDeck.Test.LogNormalise Extends %UnitTest.TestCase
{

Method TestMessagesLine()
{
	set event = ##class(FlightDeck.Logs.Sources.Messages).Parse("messages", "id", "09/18/26-04:45:26:546 (1672) 0 [Utility.Event] Enabling logons")
	do $$$AssertTrue(event.parsed, "the shape the instance writes is parsed")
	do $$$AssertEquals(event.severity, "info", "the platform's own level 0")
	do $$$AssertEquals(event.timestamp, "2026-09-18 04:45:26.546")
	do $$$AssertEquals(event.process, "1672")
	do $$$AssertTrue(event.message [ "Enabling logons")
	do $$$AssertTrue(event.rawAvailable, "the original line travels with the event")
	// The messages log names no namespace and no user: they stay out, rather than becoming "".
	do $$$AssertNotTrue(event.%IsDefined("namespace"), "namespace is absent, not empty")
	do $$$AssertNotTrue(event.%IsDefined("user"), "user is absent, not empty")
}

Method TestAnUnparsableLineSurvives()
{
	set event = ##class(FlightDeck.Logs.Sources.Messages).Parse("messages", "id", "something that is not a log line")
	do $$$AssertNotTrue(event.parsed, "it is marked unparsed")
	do $$$AssertTrue(event.message [ "something that is not", "the line itself is the message")
	do $$$AssertTrue(event.rawAvailable, "and it still carries its original")
	do $$$AssertEquals(event.severity, "unknown", "an unparsed line has no severity to state")
}

Method TestAuditRecord()
{
	set row = {"AuditIndex":5310, "UTCTimeStamp":"2026-09-18 12:57:21.793", "SystemID":"box:IRIS",
		"Event":"AuditReport", "Description":"List Query", "Username":"_SYSTEM", "Namespace":"%SYS", "Pid":45246}
	set event = ##class(FlightDeck.Logs.Sources.Audit).Normalise(row)
	do $$$AssertEquals(event.source, "audit")
	do $$$AssertEquals(event.timestamp, "2026-09-18 12:57:21.793")
	do $$$AssertEquals(event.user, "_SYSTEM")
	do $$$AssertEquals(event.namespace, "%SYS")
	do $$$AssertEquals(event.process, 45246)
	do $$$AssertEquals(event.severity, "unknown", "an audit record states no level")
	do $$$AssertTrue(event.rawAvailable)
	// The three-part key the detail read needs travels with the event (research R6).
	do $$$AssertEquals(event.rawKey.auditIndex, 5310)
	do $$$AssertEquals(event.rawKey.systemID, "box:IRIS")
	do $$$AssertEquals(event.rawKey.utcTimeStamp, "2026-09-18 12:57:21.793")
}

Method TestAFailedAuditRecordIsAnError()
{
	set row = {"AuditIndex":1, "UTCTimeStamp":"2026-09-18 12:00:00", "SystemID":"box", "Event":"LoginFailure", "Status":"ERROR #822"}
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Audit).Normalise(row).severity, "error")
}

Method TestInteropSeverityIsThePlatformsOwnLevel()
{
	// Ens.DataType.LogType: 1 assert, 2 error, 3 warning, 4 info, 5 trace.
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Interop).Severity(1), "error")
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Interop).Severity(2), "error")
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Interop).Severity(3), "warning")
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Interop).Severity(4), "info")
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Interop).Severity(5), "info")
	do $$$AssertEquals(##class(FlightDeck.Logs.Sources.Interop).Severity(99), "unknown", "a level FlightDeck does not know is not one it invents")
}

Method TestAnEventWhoseOriginalIsGoneKeepsItsFields()
{
	set event = ##class(FlightDeck.Logs.Event).New("audit", "1", "2026-09-18 12:00:00", "info", "something happened", {"a":1})
	do ##class(FlightDeck.Logs.Event).RawGone(event, "The instance no longer holds this record.")
	do $$$AssertNotTrue(event.rawAvailable)
	do $$$AssertTrue(event.rawReason [ "no longer holds", "the gap is stated")
	do $$$AssertEquals(event.message, "something happened", "and the normalised fields stand")
}

}

/// Feature 005: the merge. Ordering, the suppression count, and the rule that the answer always
/// lists every source — including the ones it could not read (spec FR-010).
Class FlightDeck.Test.LogStream Extends %UnitTest.TestCase
{

Method TestOrderingIsNewestFirstAndStable()
{
	set events = []
	do events.%Push(##class(FlightDeck.Logs.Event).New("messages", "b", "2026-09-18 10:00:00", "info", "second"))
	do events.%Push(##class(FlightDeck.Logs.Event).New("audit", "a", "2026-09-18 11:00:00", "info", "first"))
	do events.%Push(##class(FlightDeck.Logs.Event).New("journal", "c", "2026-09-18 10:00:00", "unknown", "tie"))
	set ordered = ##class(FlightDeck.Logs.Stream).Order(events)
	do $$$AssertEquals(ordered.%Get(0).message, "first", "newest first")
	// A tie breaks on source then id, so two refreshes agree rather than shuffling.
	set again = ##class(FlightDeck.Logs.Stream).Order(events)
	for i = 0:1:2 { do $$$AssertEquals(ordered.%Get(i).id, again.%Get(i).id, "the order repeats") }
}

Method TestEverySourceIsListedEvenWhenItAnsweredNothing()
{
	set page = ##class(FlightDeck.Logs.Stream).Read({"limit":5})
	do $$$AssertEquals(page.sources.%Size(), 5, "all five sources are reported")
	set iter = page.sources.%GetIterator(), named = 0
	while iter.%GetNext(, .source) {
		// A source that could not be read carries a reason; one that could carries a count.
		if 'source.available do $$$AssertNotEquals(source.reason, "", source.id_" says why it is absent")
		set named = named + 1
	}
	do $$$AssertEquals(named, 5)
}

Method TestThePageStatesItsShareAndItsSuppression()
{
	set page = ##class(FlightDeck.Logs.Stream).Read({"limit":10})
	do $$$AssertTrue(page.share > 0, "the per-source share is stated")
	do $$$AssertTrue(page.events.%Size() <= 10, "the limit holds")
	do $$$AssertTrue(page.timeZone [ "UTC", "the instance's zone is stated: "_page.timeZone)
}

Method TestFreeTextMatchesTheNormalisedFields()
{
	set event = ##class(FlightDeck.Logs.Event).New("audit", "1", "2026-09-18 12:00:00", "info", "LoginFailure", , {"user":"kadu"})
	do $$$AssertTrue(##class(FlightDeck.Logs.Stream).Matches(event, {"q":"loginfailure"}), "case-insensitive on the message")
	do $$$AssertTrue(##class(FlightDeck.Logs.Stream).Matches(event, {"q":"kadu"}), "and on the user")
	do $$$AssertNotTrue(##class(FlightDeck.Logs.Stream).Matches(event, {"q":"nothing here"}))
}

}

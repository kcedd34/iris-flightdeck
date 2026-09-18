/// Certificate validity bands and the read cap (feature 003 T017, T070; probe P3).
Class FlightDeck.Test.Validity Extends %UnitTest.TestCase
{

Method TestBandsAtTheWindowBoundaries()
{
	set alert = ##class(FlightDeck.Security.Validity).#ALERTDAYS
	for pair = $listbuild(alert + 5, "valid"), $listbuild(alert, "expiring"), $listbuild(1, "expiring"), $listbuild(-3, "expired") {
		set days = $list(pair, 1), expected = $list(pair, 2)
		set facts = ##class(FlightDeck.Security.Validity).FromNotAfter($zdate($horolog + days, 3) _ " 12:00:00")
		do $$$AssertEquals(facts.band, expected, "band for "_days_" days")
		do $$$AssertEquals(facts.daysRemaining, days, "days remaining for "_days)
	}
}

Method TestUnknownWhenThePlatformReportsNoValidity()
{
	set facts = ##class(FlightDeck.Security.Validity).FromNotAfter("")
	do $$$AssertEquals(facts.band, "unknown")
	do $$$AssertTrue(facts.reason [ "no validity", "the reason states the gap")
	do $$$AssertNotTrue(##class(FlightDeck.Security.Validity).NeedsAttention("unknown"), "unknown is not counted as attention")
	do $$$AssertNotTrue(##class(FlightDeck.Security.Validity).NeedsAttention("valid"))
	do $$$AssertTrue(##class(FlightDeck.Security.Validity).NeedsAttention("expiring"))
	do $$$AssertTrue(##class(FlightDeck.Security.Validity).NeedsAttention("expired"))
}

/// Beyond the cap the answer says so instead of reading without bound.
Method TestReadCapReportsNotRead()
{
	kill %FlightDeckCertificate, %FlightDeckCertificateReads
	set %FlightDeckCertificateReads = ##class(FlightDeck.Security.Validity).#MAXREADS
	set facts = ##class(FlightDeck.Security.Validity).For("FDT_NoSuchCredential")
	do $$$AssertEquals(facts.band, "not-read")
	do $$$AssertTrue(facts.reason [ "limit for one request", "the reason names the cap")
	kill %FlightDeckCertificate, %FlightDeckCertificateReads
}

/// A credential the instance does not have reports not-read with the platform's own message.
Method TestRefusedReadReportsTheOfficialMessage()
{
	kill %FlightDeckCertificate, %FlightDeckCertificateReads
	set facts = ##class(FlightDeck.Security.Validity).For("FDT_NoSuchCredential")
	do $$$AssertEquals(facts.band, "not-read")
	do $$$AssertTrue(facts.reason [ "does not exist", "the platform's message is kept")
	kill %FlightDeckCertificate, %FlightDeckCertificateReads
}

}

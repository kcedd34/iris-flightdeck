/// System application marking (feature 002 T024, research R2). IRIS 2026.2 never sets IsSystemApp;
/// Type carries "System". This test fails loudly if the two fields ever disagree in a way that
/// would change the workaround.
Class FlightDeck.Test.WebAppSystemMarking Extends %UnitTest.TestCase
{

Method TestMarkingFromEitherField()
{
	do $$$AssertTrue(##class(FlightDeck.Domain.Facts).IsSystemApplication({"IsSystemApp":true, "Type":"CSP"}))
	do $$$AssertTrue(##class(FlightDeck.Domain.Facts).IsSystemApplication({"IsSystemApp":false, "Type":"System,CSP"}))
	do $$$AssertNotTrue(##class(FlightDeck.Domain.Facts).IsSystemApplication({"IsSystemApp":false, "Type":"CSP"}))
}

Method TestFieldsDoNotContradictEachOther()
{
	set list = ##class(FlightDeck.Admin.Client).Get("/v2/web-apps", {"maxRows":1000}, .status)
	do $$$AssertEquals(status, 200)
	set systemByType = 0, contradictions = ""
	set iter = list.%GetIterator()
	while iter.%GetNext(, .item) {
		set byType = $zconvert(item.Type, "U") [ "SYSTEM"
		set systemByType = systemByType + byType
		if item.IsSystemApp && 'byType set contradictions = contradictions _ " " _ item.Name
	}
	do $$$AssertEquals(contradictions, "", "IsSystemApp true while Type lacks System: revisit research R2 for"_contradictions)
	do $$$AssertTrue(systemByType > 0, "the platform still marks system applications through Type")
}

}

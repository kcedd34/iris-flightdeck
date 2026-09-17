/// Secret masking in the mutation layer (feature 002 T039, Constitution VI). Uses an in-memory
/// descriptor with a secret field; the masking code is the same the service applies.
Class FlightDeck.Test.MutationMask Extends %UnitTest.TestCase
{

Method TestRowsNeverCarrySecretValues()
{
	set descriptor = {"schema":"User", "secretFields":["Password"], "target":"{name}"}
	set ctx = {"kind":"edit", "keys":{"name":"u"}, "current":{"FullName":"A", "Password":"old-S3cret"}, "proposed":{"FullName":"B", "Password":"new-S3cret"}, "changedFields":["FullName","Password"]}
	set rows = ##class(FlightDeck.Mutation.Service).Rows(descriptor, ctx)
	do $$$AssertNotTrue(rows.%ToJSON() [ "S3cret", rows.%ToJSON())
	set found = 0
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		if row.field = "Password" {
			set found = 1
			do $$$AssertTrue(row.secret)
			do $$$AssertTrue(row.changed, "changed is still reported")
			do $$$AssertNotTrue(row.%IsDefined("current") || row.%IsDefined("commanded"))
		}
	}
	do $$$AssertTrue(found)
}

Method TestErrorTextAndFingerprintCarryNoSecret()
{
	set text = ##class(FlightDeck.Mutation.Mask).Text("ERROR: value 'new-S3cret' is invalid", {"Password":"new-S3cret"}, ["Password"])
	do $$$AssertNotTrue(text [ "S3cret", text)
	set a = ##class(FlightDeck.Mutation.Fingerprint).Of({"Password":"one", "X":1}, ["Password"])
	set b = ##class(FlightDeck.Mutation.Fingerprint).Of({"X":1, "Password":"two"}, ["Password"])
	do $$$AssertNotEquals(a, b, "a changed secret still changes the fingerprint")
	do $$$AssertEquals(##class(FlightDeck.Mutation.Fingerprint).Of({"X":1, "Y":[1,true]}), ##class(FlightDeck.Mutation.Fingerprint).Of({"Y":[1,true], "X":1}), "key order does not matter")
}

Method TestRequestHeadersMasked()
{
	set masked = ##class(FlightDeck.Mutation.Mask).Request({"method":"POST", "path":"/x", "headers":{"Authorization":"Basic abc", "X-Other":"keep"}})
	do $$$AssertEquals(masked.headers.Authorization, "[secret]")
	do $$$AssertEquals(masked.headers."X-Other", "keep")
}

}

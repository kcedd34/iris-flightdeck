/// Pattern catalog (feature 002 User Story 4, T078): the shipped mutation service, driven by the
/// catalog's descriptors, grades, masks secrets, blocks, reports impact and detects a concurrent
/// change. The fixtures flag is set only for the duration of this case.
Class FlightDeck.Test.PatternCatalog Extends %UnitTest.TestCase
{

Property PreviousFlag As %String;

Method OnBeforeAllTests() As %Status
{
	set ..PreviousFlag = $get(^FlightDeck.Install("fixtures"))
	set ^FlightDeck.Install("fixtures") = 1
	kill %FlightDeckDescriptors
	quit $$$OK
}

Method OnAfterAllTests() As %Status
{
	if ..PreviousFlag = "" { kill ^FlightDeck.Install("fixtures") } else { set ^FlightDeck.Install("fixtures") = ..PreviousFlag }
	do ##class(FlightDeck.Fixture.PatternCatalog).Reset()
	quit $$$OK
}

Method OnBeforeOneTest(testname As %String) As %Status
{
	do ##class(FlightDeck.Fixture.PatternCatalog).Reset()
	quit $$$OK
}

ClassMethod Preview(operationId As %String, name As %String, proposed As %DynamicObject = "") As %DynamicObject
{
	set request = {"operationId":(operationId), "keys":{"name":(name)}}
	if $isobject(proposed) set request.proposed = proposed
	quit ##class(FlightDeck.Mutation.Service).DoPreview(request, .status)
}

Method TestInertWithoutFlag()
{
	kill ^FlightDeck.Install("fixtures")
	do $$$AssertEquals(##class(FlightDeck.Domain.Descriptor).EntityType("fixtures", "catalog-item"), "")
	do $$$AssertEquals(##class(FlightDeck.Domain.Descriptor).Mutation("PUT /fixture/catalog-item"), "")
	do $$$AssertNotTrue(##class(FlightDeck.Domain.Upstream).IsFixture("/fixture/catalog-items"))
	set ^FlightDeck.Install("fixtures") = 1
	do $$$AssertTrue($isobject(##class(FlightDeck.Domain.Descriptor).EntityType("fixtures", "catalog-item")))
}

Method TestDescriptorPredicatesAreValid()
{
	for xdata = "EntityTypes", "Mutations" {
		set data = ##class(FlightDeck.Domain.Descriptor).Load("FlightDeck.Fixture.PatternCatalog", xdata)
		set problems = []
		do ##class(FlightDeck.Domain.Descriptor).Forbidden(data, xdata, problems)
		do $$$AssertEquals(problems.%Size(), 0, xdata_" declares no privilege")
	}
	set mutation = ##class(FlightDeck.Fixture.PatternCatalog).Mutation("DELETE /fixture/catalog-item")
	do $$$AssertEquals(##class(FlightDeck.Domain.Predicate).Problem(mutation.grade.%Get(0).when, "current,proposed,isSystem,isFlightDeck,facts,request,kind"), "")
}

Method TestThreeGrades()
{
	set simple = ..Preview("PUT /fixture/catalog-item", "plain-item", {"Description":"changed"})
	do $$$AssertEquals(simple.grade, "simple")
	set reinforced = ..Preview("PUT /fixture/catalog-item", "plain-item", {"Enabled":false})
	do $$$AssertEquals(reinforced.grade, "reinforced")
	do $$$AssertEquals(reinforced.confirmText, "plain-item")
	set maximum = ..Preview("DELETE /fixture/catalog-item", "critical-item")
	do $$$AssertEquals(maximum.grade, "maximum")
	do $$$AssertTrue(maximum.consequence [ "critical")
	do $$$AssertEquals(maximum.impact.state, "ok")
	do $$$AssertNotTrue(maximum.%IsDefined("blocked") && $isobject(maximum.blocked))
}

Method TestSecretRowsCarryNoValues()
{
	do ..AssertSecretRow(..Preview("PUT /fixture/catalog-item", "plain-item", {"Secret":"new-secret-value"}), 1)
	do ..AssertSecretRow(..Preview("PUT /fixture/catalog-item", "plain-item", {"Secret":"catalog-secret-plain", "Description":"x"}), 0)
}

Method AssertSecretRow(preview As %DynamicObject, expectChanged As %Boolean)
{
	set found = 0
	set iter = preview.rows.%GetIterator()
	while iter.%GetNext(, .row) {
		continue:row.field'="Secret"
		set found = 1
		do $$$AssertTrue(row.secret)
		do $$$AssertEquals(+row.changed, expectChanged, "changed flag")
		do $$$AssertNotTrue(row.%IsDefined("current") || row.%IsDefined("commanded"), "no values")
	}
	do $$$AssertTrue(found, "secret row present")
	do $$$AssertNotTrue(preview.%ToJSON() [ "secret-value", "no proposed secret anywhere")
	do $$$AssertNotTrue(preview.%ToJSON() [ "catalog-secret-plain", "no current secret anywhere")
}

Method TestProtectedIsBlockedAndRecorded()
{
	set preview = ..Preview("DELETE /fixture/catalog-item", "protected-item")
	do $$$AssertTrue($isobject(preview.blocked))
	set response = ##class(FlightDeck.Mutation.Service).DoApply({"operationId":"DELETE /fixture/catalog-item", "keys":{"name":"protected-item"}, "fingerprint":(preview.fingerprint), "confirmation":"protected-item"}, .status)
	do $$$AssertEquals(status, 403)
	do $$$AssertEquals(response.error.code, "SELF_PROTECTION")
	do $$$AssertEquals(response.trail.result, "Blocked")
	// What matters is that the blocked delete changed nothing, not how many items the catalog seeds:
	// a fixture gains items as new pattern behaviours are added to it.
	set items = ##class(FlightDeck.Fixture.PatternCatalog).Load(), found = 0
	set iter = items.%GetIterator()
	while iter.%GetNext(, .item) { if item.Name = "protected-item" set found = 1 }
	do $$$AssertTrue(found, "the protected item is still there")
}

Method TestDriftForcesStateChanged()
{
	set preview = ..Preview("PUT /fixture/catalog-item", "plain-item", {"Description":"mine"})
	do ##class(FlightDeck.Fixture.PatternCatalog).Call("GET", "/fixture/catalog-items", {"drift":"plain-item"}, "", .status)
	set request = {"operationId":"PUT /fixture/catalog-item", "keys":{"name":"plain-item"}, "proposed":{"Description":"mine"}, "fingerprint":(preview.fingerprint)}
	set response = ##class(FlightDeck.Mutation.Service).DoApply(request, .status)
	do $$$AssertEquals(status, 409)
	do $$$AssertEquals(response.error.code, "STATE_CHANGED")
	set request.fingerprint = response.preview.fingerprint
	set response = ##class(FlightDeck.Mutation.Service).DoApply(request, .status)
	do $$$AssertEquals(status, 200)
	do $$$AssertEquals(response.result.Description, "mine")
	do $$$AssertNotTrue(response.result.%IsDefined("Secret"), "secret masked in the result")
}

}

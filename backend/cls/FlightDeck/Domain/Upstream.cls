/// The one place descriptor-driven reads and the mutation service reach an operation
/// (feature 002 research R3, R13). Official operations go to FlightDeck.Admin.Client. Pattern
/// catalog operations (path /fixture/...) go to FlightDeck.Fixture.PatternCatalog, and only when the
/// install enabled fixtures; otherwise they are unknown like any other path.
Class FlightDeck.Domain.Upstream [ Abstract ]
{

ClassMethod Call(method As %String, path As %String, query As %DynamicObject = "", body As %DynamicAbstractObject = "", Output status As %Integer, Output result As %DynamicAbstractObject, Output raw As %String) As %Status
{
	if ..IsFixture(path) {
		quit $classmethod(##class(FlightDeck.Domain.Fixtures).#CATALOG, "Call", method, path, query, body, .status, .result, .raw)
	}
	quit ##class(FlightDeck.Admin.Client).Call(method, path, query, body, .status, .result, .raw)
}

ClassMethod IsFixture(path As %String) As %Boolean
{
	quit ($extract(path, 1, 9) = "/fixture/") && ##class(FlightDeck.Domain.Fixtures).Enabled()
}

}

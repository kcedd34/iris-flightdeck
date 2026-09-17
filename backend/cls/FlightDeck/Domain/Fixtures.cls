/// Test-only descriptors for the pattern catalog (feature 002 research R13). Inert unless the e2e
/// setup sets ^FlightDeck.Install("fixtures") = 1 on a test install; the catalog's entities live in
/// the IRIS session and never touch IRIS configuration.
Class FlightDeck.Domain.Fixtures [ Abstract ]
{

Parameter CATALOG = "FlightDeck.Fixture.PatternCatalog";

ClassMethod Enabled() As %Boolean
{
	quit +$get(^FlightDeck.Install("fixtures")) && ##class(%Dictionary.CompiledClass).%ExistsId(..#CATALOG)
}

ClassMethod EntityType(domain As %String, entityType As %String) As %DynamicObject
{
	quit $classmethod(..#CATALOG, "EntityType", domain, entityType)
}

ClassMethod Mutation(operationId As %String) As %DynamicObject
{
	quit $classmethod(..#CATALOG, "Mutation", operationId)
}

}

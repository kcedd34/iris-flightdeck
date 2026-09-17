/// REST service discovery (feature 002 T063, research R9): both kinds of services, honest
/// specification flags, FlightDeck's own published specification, no FlightDeck special case.
Class FlightDeck.Test.RestDiscovery Extends %UnitTest.TestCase
{

Method Services() As %DynamicObject
{
	set byName = {}
	set iter = ##class(FlightDeck.Rest.Discovery).Services().services.%GetIterator()
	while iter.%GetNext(, .service) { do byName.%Set(service.name, service) }
	quit byName
}

Method TestBothKindsWithHonestFlags()
{
	set services = ..Services()
	do $$$AssertEquals(services."/api/iam".kind, "specification-first")
	do $$$AssertTrue(services."/api/iam".hasSpecification)
	do $$$AssertEquals(services."/api/monitor".kind, "hand-coded")
	do $$$AssertNotTrue(services."/api/monitor".hasSpecification, "a UrlMap-generated document is not a specification")
	do $$$AssertTrue(services."/api/monitor".routesReportedByPlatform)
	do $$$AssertNotTrue(services."/api/admin".hasSpecification)
	do $$$AssertTrue(services."%Api.InteropEditors.v1".hasSpecification)
	do $$$AssertEquals(services."%Api.InteropEditors.v1".webApplication, "")
}

Method TestFlightDeckPublishesItsSpecification()
{
	set flightdeck = ..Services()."/api/flightdeck"
	do $$$AssertTrue(flightdeck.hasSpecification)
	do $$$AssertEquals(flightdeck.specificationSource, "published")
	set spec = ##class(FlightDeck.Rest.Discovery).Specification(flightdeck, .status, .error)
	do $$$AssertEquals(status, 200, error)
	do $$$AssertEquals(spec.format, "openapi-3.0")
	do $$$AssertEquals(spec.document.%ToJSON(), ##class(FlightDeck.API.OpenAPI).Document().%ToJSON(), "the served document, not a reconstruction")
}

Method TestRoutesForHandCoded()
{
	set spec = ##class(FlightDeck.Rest.Discovery).Specification(..Services()."/api/monitor", .status)
	do $$$AssertEquals(spec.format, "routes")
	do $$$AssertTrue(spec.routes.%Size() > 0)
}

Method TestDiscoveryHasNoFlightDeckSpecialCase()
{
	for class = "FlightDeck.Rest.Discovery" {
		set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = ?", class)
		while rs.%Next() {
			set code = ##class(%Dictionary.MethodDefinition).%OpenId(class_"||"_rs.Name).Implementation.Read(1000000)
			do $$$AssertNotTrue((code [ "/api/flightdeck") || (code [ "FlightDeck.API"), class_":"_rs.Name_" names FlightDeck")
		}
	}
}

}

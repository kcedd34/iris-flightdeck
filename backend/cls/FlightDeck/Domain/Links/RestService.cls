/// Link provider "rest-service": the REST service a web application exposes, in the REST APIs
/// section, with whether it has a specification (feature 002 research R9).
Class FlightDeck.Domain.Links.RestService [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit ""
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	quit:'entity.facts.restDispatcher ""
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("rest-service", "REST service")
	set service = ##class(FlightDeck.Rest.Discovery).Find(entity.keys.name)
	if '$isobject(service) {
		set group.state = "undetermined"
		set group.reason = "The platform's REST discovery did not report this application to you."
		quit group
	}
	set group.label = $select(service.hasSpecification:"OpenAPI specification", 1:"REST service without a specification")
	set group.count = 1
	do group.items.%Push({"entityType":"rest-service", "domain":"web-apps", "displayName":(service.webApplication), "keys":{"webApplication":(service.webApplication)}, "detail":($select(service.hasSpecification:"specification", 1:"routes only"))})
	quit group
}

}

/// Impact provider "webapp-impact" (RN-FD-11, feature 002 research R6, spec FR-010): who loses or
/// changes access when a web application is disabled, deleted or its protection changes. Composed
/// from official reads; when they are refused, the impact says it could not be determined and why.
Class FlightDeck.Domain.Links.WebAppImpact [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit ##class(FlightDeck.Domain.Links.RoleOwners).Operations() _ ##class(FlightDeck.Domain.Links.ResourcePublic).Operations()
}

/// Returns {state, summary, users[], objects[], reason}.
ClassMethod Impact(current As %DynamicObject) As %DynamicObject
{
	set impact = {"state":"ok", "users":[], "objects":[]}
	do impact.%Set("reason", "", "null")
	set resource = current.Resource
	if resource = "" {
		set impact.summary = "Every user who can reach namespace "_current.NameSpace_" (no resource restricts this application)"
		quit impact
	}
	set permission = ##class(FlightDeck.Domain.Links.ResourcePublic).Permission(resource, .failure)
	if $isobject(failure) quit ..Undetermined(impact, failure)
	if permission '= "" {
		set impact.summary = "Every user: "_resource_" grants "_permission_" publicly"
		quit impact
	}
	set users = ##class(FlightDeck.Domain.Links.RoleOwners).Users(resource, .failure)
	if $isobject(failure) quit ..Undetermined(impact, failure)
	set iter = users.%GetIterator()
	while iter.%GetNext(.name) { do impact.users.%Push(name) }
	set impact.summary = impact.users.%Size()_" users with access through roles granting "_resource
	quit impact
}

ClassMethod Undetermined(impact As %DynamicObject, failure As %DynamicObject) As %DynamicObject
{
	set impact.state = "undetermined"
	set group = ##class(FlightDeck.Domain.LinkProviders).FromFailure(##class(FlightDeck.Domain.LinkProviders).NewGroup("impact", "impact"), failure.operationId, failure.status, failure.json, failure.raw)
	set impact.summary = "The impact could not be determined."
	set impact.reason = group.reason
	quit impact
}

}

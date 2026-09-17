/// Registry of link providers named by entity-type descriptors (feature 002 data-model §1.3).
/// Every provider composes official reads only, declares the operations it calls (for composite
/// capabilities), and answers one LinkGroup or "" when the group does not apply.
Class FlightDeck.Domain.LinkProviders [ Abstract ]
{

ClassMethod Class(provider As %String) As %String
{
	quit $case(provider,
		"resource-roles":"FlightDeck.Domain.Links.ResourceRoles",
		"role-owners":"FlightDeck.Domain.Links.RoleOwners",
		"resource-public":"FlightDeck.Domain.Links.ResourcePublic",
		"rest-service":"FlightDeck.Domain.Links.RestService",
		:"")
}

/// A LinkGroup skeleton.
ClassMethod NewGroup(provider As %String, label As %String, direction As %String = "out") As %DynamicObject
{
	set group = {"provider":(provider), "direction":(direction), "label":(label), "state":"ok", "items":[]}
	do group.%Set("reason", "", "null")
	do group.%Set("count", "", "null")
	quit group
}

/// Marks a group as refused or failed from an official call's answer, verbatim.
ClassMethod FromFailure(group As %DynamicObject, operationId As %String, status As %Integer, json As %DynamicAbstractObject, raw As %String) As %DynamicObject
{
	if status = 403 {
		set group.state = "forbidden"
		set op = ##class(FlightDeck.Capability.Map).Operation(operationId)
		set group.reason = $select($isobject(op):##class(FlightDeck.API.Response).RequiresMessage(op.requires), 1:##class(FlightDeck.Admin.Client).ErrorText(json, raw))
	} elseif status = 501 {
		set group.state = "unavailable"
		set group.reason = ##class(FlightDeck.Admin.Client).UnavailableReason(operationId)
	} else {
		set group.state = "undetermined"
		set group.reason = ##class(FlightDeck.Admin.Client).ErrorText(json, raw)
	}
	quit group
}

/// LinkItem.
ClassMethod Item(entityType As %String, domain As %String, name As %String, detail As %String = "") As %DynamicObject
{
	set item = {"entityType":(entityType), "domain":(domain), "displayName":(name), "keys":{"name":(name)}}
	do item.%Set("detail", detail, $select(detail="":"null", 1:"string"))
	quit item
}

}

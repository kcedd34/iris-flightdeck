/// Link provider "role-owners": users holding a role that grants the entity's resource, directly
/// or as an escalation role (GET /v2/security/role/owners; feature 002 research R6).
Class FlightDeck.Domain.Links.RoleOwners [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit ##class(FlightDeck.Domain.Links.ResourceRoles).Operations() _ $listbuild("GET /v2/security/role/owners")
}

ClassMethod Group(entity As %DynamicObject) As %DynamicObject
{
	set resource = entity.object.Resource
	quit:resource="" ""
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("role-owners", "users have access through these roles", "in")
	set users = ..Users(resource, .failure)
	if $isobject(failure) quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, failure.operationId, failure.status, failure.json, failure.raw)
	set iter = users.%GetIterator()
	while iter.%GetNext(.name, .detail) {
		do group.items.%Push(##class(FlightDeck.Domain.LinkProviders).Item("user", "permissions", name, detail))
	}
	set group.count = group.items.%Size()
	quit group
}

/// {userName: "through role A, role B (escalation)"} for the roles granting a resource.
ClassMethod Users(resource As %String, Output failure As %DynamicObject) As %DynamicObject
{
	set roles = ##class(FlightDeck.Domain.Links.ResourceRoles).Granting(resource, .failure)
	quit:$isobject(failure) {}
	kill via
	set iter = roles.%GetIterator()
	while iter.%GetNext(, .grant) {
		set owners = ##class(FlightDeck.Admin.Client).Get("/v2/security/role/owners", {"name":(grant.role), "maxRows":1000}, .status, .raw)
		if status '= 200 {
			set failure = {"operationId":"GET /v2/security/role/owners", "status":(status), "json":"", "raw":(raw)}
			quit
		}
		set o = owners.%GetIterator()
		while o.%GetNext(, .owner) {
			continue:owner.Type'["User"
			// A role held both directly and as an escalation role is listed once, as direct.
			set kind = $select(owner.Type["escalation":"escalation", 1:"direct")
			if kind = "direct" { set via(owner.Name, grant.role) = "" } elseif '$data(via(owner.Name, grant.role)) { set via(owner.Name, grant.role) = " (escalation)" }
		}
	}
	quit:$isobject(failure) {}
	set users = {}, name = ""
	for {
		set name = $order(via(name))
		quit:name=""
		set text = "", role = ""
		for {
			set role = $order(via(name, role))
			quit:role=""
			set text = text _ $select(text="":"through ", 1:", ") _ role _ via(name, role)
		}
		do users.%Set(name, text)
	}
	quit users
}

}

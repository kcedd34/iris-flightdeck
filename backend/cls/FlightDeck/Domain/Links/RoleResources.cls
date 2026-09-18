/// Link provider "role-resources" (feature 003 US1): the resources a role grants, directly and
/// through the roles it inherits, with the permissions the official API reports.
Class FlightDeck.Domain.Links.RoleResources [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/role")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("role-resources", "resources this role grants", "out")
	set answer = ##class(FlightDeck.Domain.Links.RoleGraph).Expand([{"role":(entity.keys.name), "kind":"role"}])
	set iter = answer.roles.%GetIterator()
	while iter.%GetNext(, .entry) {
		continue:'$isobject(entry.resources)
		set resources = entry.resources.%GetIterator()
		while resources.%GetNext(, .grant) {
			set detail = grant.Permissions _ $select(entry.path.%Size() > 1:" through " _ ##class(FlightDeck.Domain.Links.RoleGraph).ChainText(entry.path), 1:"")
			do group.items.%Push(##class(FlightDeck.Domain.LinkProviders).Item("resource", "permissions", grant.Name, detail))
		}
	}
	set group.count = group.items.%Size()
	if answer.truncated {
		do group.%Set("truncated", 1, "boolean")
		set group.state = "undetermined"
		set group.reason = "Not expanded: " _ ##class(FlightDeck.Domain.Links.RoleHolders).PathText(answer.unread)
	}
	quit group
}

}

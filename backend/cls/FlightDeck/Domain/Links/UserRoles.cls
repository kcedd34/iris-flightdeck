/// Link provider "user-roles" (feature 003 spec FR-004, US1): the roles a user holds, direct and
/// escalation, each with the chain that reaches it through GrantedRoles.
/// <p>An account whose authentication methods include delegated access or LDAP may also receive
/// roles at login from that mechanism. The official API does not report which, so the group says
/// that the portal does not manage them there and claims nothing more (research R3).
Class FlightDeck.Domain.Links.UserRoles [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/role")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("user-roles", "roles this user holds", "out")
	set seeds = ##class(FlightDeck.Domain.Links.RoleGraph).SeedsForUser(entity.object)
	if seeds.%Size() = 0 {
		set group.label = "This user holds no role"
		set group.count = 0
		do ..ExternalNote(group, entity)
		quit group
	}
	set answer = ##class(FlightDeck.Domain.Links.RoleGraph).Expand(seeds)
	set iter = answer.roles.%GetIterator()
	while iter.%GetNext(, .entry) {
		set detail = $select(entry.path.%Size() = 1:$select(entry.kind="escalation":"escalation role", 1:"direct"), 1:"through " _ ##class(FlightDeck.Domain.Links.RoleGraph).ChainText(entry.path))
		do group.items.%Push(##class(FlightDeck.Domain.LinkProviders).Item("role", "permissions", entry.role, detail))
	}
	set group.count = answer.roles.%Size()
	if answer.truncated {
		do group.%Set("truncated", 1, "boolean")
		set group.state = "undetermined"
		set group.reason = "Part of the chain could not be expanded: " _ ##class(FlightDeck.Domain.Links.RoleHolders).PathText(answer.unread)
	}
	do ..ExternalNote(group, entity)
	quit group
}

/// Roles may also arrive at login from a delegated mechanism or LDAP. The official API does not say
/// which, so the group states the mechanism and claims nothing about individual roles (FR-004).
ClassMethod ExternalNote(group As %DynamicObject, entity As %DynamicObject)
{
	quit:''entity.facts.externalAuthentication=0
	set note = "This account also authenticates through a delegated mechanism or LDAP, which may assign roles at login. FlightDeck does not manage those here."
	set current = $select($isobject(group.reason):"", 1:group.reason)
	set group.reason = $select(current="":note, 1:current _ " " _ note)
}

}

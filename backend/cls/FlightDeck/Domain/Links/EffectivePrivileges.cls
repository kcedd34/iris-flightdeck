/// Link provider "effective-privileges" (RN-FD-10, feature 003 spec FR-003): every permission a user
/// or role effectively holds, each with the chain of roles that grants it.
/// <p>A privilege is never shown without its origin, and a privilege whose chain could not be
/// expanded is not shown as if it were complete: the group reports what it could not read.
/// <p>Composed from GET /v2/security/user and GET /v2/security/role only (Constitution I).
Class FlightDeck.Domain.Links.EffectivePrivileges [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/role")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("effective-privileges", "privileges, with the chain that grants each one", "out")
	set seeds = ..Seeds(entity)
	if seeds.%Size() = 0 {
		set group.label = "No role grants this one any privilege"
		set group.count = 0
		quit group
	}
	set answer = ##class(FlightDeck.Domain.Links.RoleGraph).Expand(seeds)
	// resource + permission -> the chains that grant it, in the order they were reached.
	kill rows
	set order = 0
	set iter = answer.roles.%GetIterator()
	while iter.%GetNext(, .entry) {
		continue:'$isobject(entry.resources)
		set resources = entry.resources.%GetIterator()
		while resources.%GetNext(, .grant) {
			set key = grant.Name _ "|" _ grant.Permissions
			if '$data(rows(key)) set order = order + 1, rows(key) = $listbuild(order, grant.Name, grant.Permissions, "")
			set chain = ##class(FlightDeck.Domain.Links.RoleHolders).PathText(entry.path)
			set chain = chain _ $select(entry.kind="escalation":" (escalation)", 1:"")
			set existing = $list(rows(key), 4)
			set $list(rows(key), 4) = existing _ $select(existing="":"", 1:"; ") _ chain
		}
	}
	// Emit in discovery order, so direct grants come before inherited ones.
	kill ordered
	set key = ""
	for { set key = $order(rows(key)) quit:key=""  set ordered($list(rows(key), 1)) = rows(key) }
	set index = ""
	for {
		set index = $order(ordered(index)) quit:index=""
		set row = ordered(index)
		set name = $list(row, 2), permissions = $list(row, 3), chains = $list(row, 4)
		do group.items.%Push(##class(FlightDeck.Domain.LinkProviders).Item("resource", "permissions", name _ ":" _ permissions, "via " _ chains))
	}
	set group.count = group.items.%Size()
	if answer.truncated {
		do group.%Set("truncated", 1, "boolean")
		set group.state = "undetermined"
		set group.reason = "These privileges are what could be read. Not expanded: " _ ##class(FlightDeck.Domain.Links.RoleHolders).PathText(answer.unread)
	}
	quit group
}

/// A user's seeds are its roles; a role's seed is itself.
ClassMethod Seeds(entity As %DynamicObject) As %DynamicArray
{
	if entity.entityType = "role" quit [{"role":(entity.keys.name), "kind":"role"}]
	quit ##class(FlightDeck.Domain.Links.RoleGraph).SeedsForUser(entity.object)
}

}

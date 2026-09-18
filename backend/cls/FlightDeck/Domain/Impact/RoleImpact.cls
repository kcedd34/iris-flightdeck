/// Impact of a change to a role or to a user's roles (RN-FD-11, feature 003 spec FR-008, FR-009):
/// who loses access and what becomes unreachable, computed on the server before the confirmation.
/// <p>Three states, never a fourth: `ok` with its lists, `none` when nothing is affected, and
/// `undetermined` with the reason when a read the answer needs was refused or capped. An empty list
/// is only ever "nothing is affected", never "could not tell".
Class FlightDeck.Domain.Impact.RoleImpact [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/role", "GET /v2/security/role/owners", "GET /v2/web-apps")
}

/// ctx carries the whole mutation context: current, proposed and keys.
ClassMethod Impact(current As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	set entityType = $piece(##class(FlightDeck.Domain.Descriptor).Mutation(ctx.operationId).entityType, "/", 2)
	if entityType = "user" quit ..UserImpact(ctx)
	quit ..RoleImpact(ctx)
}

/// A user's own change: the privileges that user loses.
ClassMethod UserImpact(ctx As %DynamicObject) As %DynamicObject
{
	set name = ctx.keys.name
	set before = ..Privileges(ctx.current, .completeBefore, .unreadBefore)
	set after = ..Privileges($select(ctx.kind="delete":{}, 1:##class(FlightDeck.Mutation.Service).Proposed(ctx)), .completeAfter, .unreadAfter)
	if 'completeBefore || 'completeAfter {
		quit {"state":"undetermined", "summary":("The privileges " _ name _ " would lose could not be determined."), "reason":(unreadBefore _ unreadAfter)}
	}
	set lost = []
	set iter = before.%GetIterator()
	while iter.%GetNext(.privilege) { if 'after.%IsDefined(privilege) do lost.%Push(privilege) }
	if lost.%Size() = 0 quit {"state":"none", "summary":(name _ " loses no privilege.")}
	quit {"state":"ok", "summary":(name _ " loses " _ lost.%Size() _ " " _ $select(lost.%Size()=1:"privilege", 1:"privileges") _ "."), "users":[(name)], "objects":(..Objects(lost))}
}

/// A role's change or deletion: the users who hold it and the privileges they lose with it.
ClassMethod RoleImpact(ctx As %DynamicObject) As %DynamicObject
{
	set role = ctx.keys.name
	set answer = ##class(FlightDeck.Domain.Links.RoleHolders).Users(role)
	if answer.truncated {
		quit {"state":"undetermined", "summary":("The users who hold " _ role _ " could not all be read."), "reason":(##class(FlightDeck.Domain.Links.RoleHolders).PathText(answer.unread))}
	}
	set before = ..RolePrivileges(ctx.current, .completeBefore, .unreadBefore)
	set after = ..RolePrivileges($select(ctx.kind="delete":{}, 1:##class(FlightDeck.Mutation.Service).Proposed(ctx)), .completeAfter, .unreadAfter)
	if 'completeBefore || 'completeAfter {
		quit {"state":"undetermined", "summary":("What " _ role _ " grants could not be determined."), "reason":(unreadBefore _ unreadAfter)}
	}
	set lost = []
	set iter = before.%GetIterator()
	while iter.%GetNext(.privilege) { if 'after.%IsDefined(privilege) do lost.%Push(privilege) }
	set users = []
	set iter = answer.users.%GetIterator()
	while iter.%GetNext(, .user) { do users.%Push(user.name) }
	if (lost.%Size() = 0) && (users.%Size() = 0) quit {"state":"none", "summary":"Nobody holds this role, and it grants nothing that changes."}
	if lost.%Size() = 0 quit {"state":"none", "summary":($select(users.%Size()=1:"1 user holds this role, and it grants nothing that changes.", 1:users.%Size() _ " users hold this role, and it grants nothing that changes."))}
	set summary = $select(users.%Size()=1:"1 user loses", 1:users.%Size() _ " users lose") _ " " _ lost.%Size() _ " " _ $select(lost.%Size()=1:"privilege", 1:"privileges") _ "."
	quit {"state":"ok", "summary":(summary), "users":(users), "objects":(..Objects(lost))}
}

/// The privileges a user object holds, as a set "resource:permission".
ClassMethod Privileges(user As %DynamicObject, Output complete As %Boolean, Output unread As %String) As %DynamicObject
{
	set complete = 1, unread = "", out = {}
	quit:'$isobject(user) out
	set seeds = ##class(FlightDeck.Domain.Links.RoleGraph).SeedsForUser(user)
	quit:seeds.%Size()=0 out
	set answer = ##class(FlightDeck.Domain.Links.RoleGraph).Expand(seeds)
	if answer.truncated set complete = 0, unread = ##class(FlightDeck.Domain.Links.RoleHolders).PathText(answer.unread)
	do ..Collect(answer, out)
	quit out
}

/// The privileges a role object grants, directly and through the roles it inherits.
ClassMethod RolePrivileges(role As %DynamicObject, Output complete As %Boolean, Output unread As %String) As %DynamicObject
{
	set complete = 1, unread = "", out = {}
	quit:'$isobject(role) out
	// The role's own resources, plus everything its granted roles reach.
	if $isobject(role.Resources) {
		set iter = role.Resources.%GetIterator()
		while iter.%GetNext(, .grant) { do out.%Set(grant.Name _ ":" _ grant.Permissions, 1, "number") }
	}
	quit:'$isobject(role.GrantedRoles) out
	set seeds = []
	set iter = role.GrantedRoles.%GetIterator()
	while iter.%GetNext(, .name) { do seeds.%Push({"role":(name), "kind":"role"}) }
	quit:seeds.%Size()=0 out
	set answer = ##class(FlightDeck.Domain.Links.RoleGraph).Expand(seeds)
	if answer.truncated set complete = 0, unread = ##class(FlightDeck.Domain.Links.RoleHolders).PathText(answer.unread)
	do ..Collect(answer, out)
	quit out
}

ClassMethod Collect(answer As %DynamicObject, out As %DynamicObject)
{
	set iter = answer.roles.%GetIterator()
	while iter.%GetNext(, .entry) {
		continue:'$isobject(entry.resources)
		set resources = entry.resources.%GetIterator()
		while resources.%GetNext(, .grant) { do out.%Set(grant.Name _ ":" _ grant.Permissions, 1, "number") }
	}
}

/// The lost privileges as link items, so the dry-run names what becomes unreachable.
ClassMethod Objects(lost As %DynamicArray) As %DynamicArray
{
	set objects = []
	set iter = lost.%GetIterator()
	while iter.%GetNext(, .privilege) {
		do objects.%Push(##class(FlightDeck.Domain.LinkProviders).Item("resource", "permissions", $piece(privilege, ":", 1), $piece(privilege, ":", 2)))
	}
	quit objects
}

}

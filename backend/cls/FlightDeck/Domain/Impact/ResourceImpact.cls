/// Impact of changing or deleting a resource (RN-FD-11): the roles that grant it, the users behind
/// those roles, and the objects it protects. Undetermined whenever a needed read was refused.
Class FlightDeck.Domain.Impact.ResourceImpact [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/roles", "GET /v2/security/role", "GET /v2/security/role/owners", "GET /v2/web-apps", "GET /v2/wallet/collections")
}

ClassMethod Impact(current As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	set resource = ctx.keys.name
	set entity = {"entityType":"resource", "keys":{"name":(resource)}, "object":(ctx.current), "facts":{}}
	set roles = ##class(FlightDeck.Domain.Links.ResourceRoles).Group(entity)
	if roles.state '= "ok" {
		quit {"state":"undetermined", "summary":("The roles that grant " _ resource _ " could not be read."), "reason":(roles.reason)}
	}
	set objects = ##class(FlightDeck.Domain.Links.ResourceObjects).Group(entity)
	set users = [], unread = ""
	set iter = roles.items.%GetIterator()
	while iter.%GetNext(, .item) {
		set answer = ##class(FlightDeck.Domain.Links.RoleHolders).Users(item.displayName)
		if answer.truncated set unread = unread _ $select(unread="":"", 1:", ") _ ##class(FlightDeck.Domain.Links.RoleHolders).PathText(answer.unread)
		set holders = answer.users.%GetIterator()
		while holders.%GetNext(, .user) { do:'##class(FlightDeck.Domain.Predicate).ArrayHas(users, user.name) users.%Push(user.name) }
	}
	if unread '= "" {
		quit {"state":"undetermined", "summary":("The users who would lose access to " _ resource _ " could not all be read."), "reason":(unread)}
	}
	if (users.%Size() = 0) && (objects.items.%Size() = 0) {
		quit {"state":"none", "summary":("Nothing holds or is protected by " _ resource _ ".")}
	}
	set summary = $select(users.%Size()=1:"1 user loses", 1:users.%Size() _ " users lose") _ " access through " _ roles.items.%Size() _ " " _ $select(roles.items.%Size()=1:"role", 1:"roles")
		_ $select(objects.items.%Size()>0:", and " _ objects.items.%Size() _ " " _ $select(objects.items.%Size()=1:"object becomes", 1:"objects become") _ " unprotected", 1:"") _ "."
	quit {"state":"ok", "summary":(summary), "users":(users), "objects":(objects.items)}
}

}

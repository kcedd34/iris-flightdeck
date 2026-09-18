/// Link provider "wallet-users" (feature 003 spec FR-016, PRD UC06-4): who can use a collection's
/// secrets — its resource, the roles that grant it, and the users who hold those roles.
Class FlightDeck.Domain.Links.WalletUsers [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/roles", "GET /v2/security/role", "GET /v2/security/role/owners")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("wallet-users", "users can use these secrets", "in")
	// The collection names the resource with the permission it requires ("FD_Demo_Reports:READ").
	set resource = $piece(entity.object.UseResource, ":", 1)
	if resource = "" {
		set group.label = "No resource restricts the use of these secrets"
		set group.count = 0
		quit group
	}
	set roles = ##class(FlightDeck.Domain.Links.ResourceRoles).Granting(resource, .failure)
	if $isobject(failure) quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, failure.operationId, failure.status, failure.json, failure.raw)
	set unread = "", seen = ""
	kill seenUser
	set iter = roles.%GetIterator()
	while iter.%GetNext(, .grant) {
		set answer = ##class(FlightDeck.Domain.Links.RoleHolders).Users(grant.role)
		if answer.truncated set unread = unread _ $select(unread="":"", 1:", ") _ ##class(FlightDeck.Domain.Links.RoleHolders).PathText(answer.unread)
		set users = answer.users.%GetIterator()
		while users.%GetNext(, .user) {
			continue:$data(seenUser(user.name))
			set seenUser(user.name) = ""
			do group.items.%Push(##class(FlightDeck.Domain.LinkProviders).Item("user", "permissions", user.name, "through " _ grant.role))
		}
	}
	set group.count = group.items.%Size()
	if unread '= "" {
		set group.state = "undetermined"
		set group.reason = "Part of the chain could not be read: " _ unread
	}
	quit group
}

}

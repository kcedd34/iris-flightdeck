/// Impact of granting or revoking a SQL privilege (RN-FD-11): the grantee, and when the grantee is a
/// role, the users who hold it. The official listing already resolves provenance, so nothing here
/// recomputes a chain (probe P4).
Class FlightDeck.Domain.Impact.SqlPrivilegeImpact [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/role/owners")
}

ClassMethod Impact(current As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	set grantee = ctx.params.grantee
	set object = $select(ctx.params.%IsDefined("object"):ctx.params.object, 1:ctx.params.%Get("privilege"))
	set answer = ##class(FlightDeck.Domain.Links.RoleHolders).Users(grantee)
	if answer.truncated {
		quit {"state":"undetermined", "summary":("Who would lose " _ object _ " could not be determined."), "reason":(##class(FlightDeck.Domain.Links.RoleHolders).PathText(answer.unread))}
	}
	set users = []
	set iter = answer.users.%GetIterator()
	while iter.%GetNext(, .user) { do users.%Push(user.name) }
	if users.%Size() = 0 quit {"state":"none", "summary":("Only " _ grantee _ " is affected: no user holds it.")}
	quit {"state":"ok", "summary":($select(users.%Size()=1:"1 user holds", 1:users.%Size() _ " users hold") _ " " _ grantee _ " and is affected by this change."), "users":(users), "objects":[]}
}

}

/// Inverse traversal of the role graph (feature 003 probe finding B): the users who hold a role.
/// <p>`GET /v2/security/role/owners` answers with the **direct** owners of a role, and an owner may
/// itself be a role (`Type: "Role"`). A user three levels below therefore never appears in one call,
/// which is why this walk exists. It uses the same cycle guard and caps as the forward traversal.
Class FlightDeck.Domain.Links.RoleHolders [ Abstract ]
{

Parameter MAXROLES = 200;

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/role/owners")
}

/// Link group: the users who hold this role, with the chain that reaches each one.
ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set role = entity.keys.name
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("role-holders", "users hold this role", "in")
	set answer = ..Users(role)
	set iter = answer.users.%GetIterator()
	while iter.%GetNext(, .user) {
		set via = user.path
		set detail = $select(via.%Size() > 1:"through "_..PathText(via), 1:"directly")
		do group.items.%Push(##class(FlightDeck.Domain.LinkProviders).Item("user", "permissions", user.name, detail))
	}
	set group.count = answer.users.%Size()
	if answer.truncated {
		do group.%Set("truncated", 1, "boolean")
		set group.state = "undetermined"
		set group.reason = "Part of the chain could not be read: " _ ..PathText(answer.unread)
	}
	quit group
}

/// "A, B and C" from a dynamic array, for a reason a person reads.
ClassMethod PathText(values As %DynamicArray) As %String
{
	set text = "", iter = values.%GetIterator()
	while iter.%GetNext(, .value) { set text = text _ $select(text="":"", 1:", ") _ value }
	quit text
}

/// Direct owners of one role, cached per request: [{Name, Type, AdminOption}].
ClassMethod Owners(role As %String, Output status As %Integer, Output json As %DynamicAbstractObject, Output raw As %String) As %DynamicArray
{
	if $data(%FlightDeckRoleOwners(role)) {
		set cached = %FlightDeckRoleOwners(role)
		set status = $list(cached, 1), raw = $list(cached, 2)
		quit $select($list(cached, 3)="":[], 1:##class(%DynamicAbstractObject).%FromJSON($list(cached, 3)))
	}
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/security/role/owners", {"name":(role), "maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	set result = $select((status=200) && $isobject($get(json)) && $isobject(json.result):json.result, 1:[])
	set %FlightDeckRoleOwners(role) = $listbuild(status, $get(raw), result.%ToJSON())
	quit result
}

/// Users holding a role, directly or through another role that holds it.
/// Returns {"users":[{"name","path":[roles...]}], "truncated":bool, "unread":[...]}.
ClassMethod Users(role As %String) As %DynamicObject
{
	set out = {"users":[], "unread":[]}
	set truncated = 0, count = 0
	kill visited, seen
	set queue = [{"role":(role), "path":[(role)]}], head = 0
	while head < queue.%Size() {
		set node = queue.%Get(head), head = head + 1
		continue:$data(visited(node.role))
		set visited(node.role) = ""
		set count = count + 1
		if count > ..#MAXROLES {
			set truncated = 1
			do out.unread.%Push(node.role)
			continue
		}
		set owners = ..Owners(node.role, .status, .json, .raw)
		if status '= 200 {
			set truncated = 1
			do out.unread.%Push(node.role_": "_##class(FlightDeck.Admin.Client).ErrorText(json, $get(raw)))
			continue
		}
		set iter = owners.%GetIterator()
		while iter.%GetNext(, .owner) {
			if owner.Type = "Role" {
				continue:$data(visited(owner.Name))
				set path = ##class(%DynamicAbstractObject).%FromJSON(node.path.%ToJSON())
				do path.%Push(owner.Name)
				do queue.%Push({"role":(owner.Name), "path":(path)})
				continue
			}
			continue:$data(seen(owner.Name))
			set seen(owner.Name) = ""
			do out.users.%Push({"name":(owner.Name), "path":(node.path)})
		}
	}
	do out.%Set("truncated", truncated, "boolean")
	quit out
}

}

/// Forward traversal of the role graph (feature 003 research R1, probe P2): from a set of roles to
/// every role they reach through GrantedRoles, keeping the path that reached each one.
/// <p>The official API reports one level at a time (`GrantedRoles` on the role detail), so the
/// traversal is required and is FlightDeck's own composition of official reads, never a
/// reimplementation of the platform's security model.
/// <p>Bounded on purpose: a cycle guard, a depth cap and a role cap. When a cap stops the walk, or a
/// read is refused, the answer says so and names what was not expanded; it never pretends to be
/// complete (Constitution VIII).
Class FlightDeck.Domain.Links.RoleGraph [ Abstract ]
{

Parameter MAXROLES = 200;

Parameter MAXDEPTH = 10;

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/role")
}

/// One role's official detail, cached per request. status is 200, or the official failure.
ClassMethod Detail(role As %String, Output status As %Integer, Output json As %DynamicAbstractObject, Output raw As %String) As %DynamicObject
{
	if $data(%FlightDeckRoleDetail(role)) {
		set cached = %FlightDeckRoleDetail(role)
		set status = $list(cached, 1), raw = $list(cached, 2)
		set json = $select($list(cached, 3)="":"", 1:##class(%DynamicAbstractObject).%FromJSON($list(cached, 3)))
		quit $select(status=200:json.result, 1:"")
	}
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/security/role", {"name":(role)}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	set %FlightDeckRoleDetail(role) = $listbuild(status, $get(raw), $select($isobject($get(json)):json.%ToJSON(), 1:""))
	quit $select(status=200 && $isobject(json):json.result, 1:"")
}

/// Every role reachable from the seeds, each with the chain that reaches it.
/// <p>seeds: [{"role":"FD_Ops", "kind":"role"}] (kind is carried through, for example "escalation").
/// Returns {"roles":[{"role","kind","path":[...],"resources":[...]}], "truncated":bool, "unread":[...]}.
ClassMethod Expand(seeds As %DynamicArray) As %DynamicObject
{
	set out = {"roles":[], "unread":[]}
	set truncated = 0, count = 0
	kill visited
	// Breadth-first, so the shortest chain to a role is the one reported first.
	set queue = [], iter = seeds.%GetIterator()
	while iter.%GetNext(, .seed) {
		do queue.%Push({"role":(seed.role), "kind":(seed.kind), "path":[(seed.role)], "depth":1})
	}
	set head = 0
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
		set detail = ..Detail(node.role, .status, .json, .raw)
		if status '= 200 {
			set truncated = 1
			do out.unread.%Push(node.role_": "_##class(FlightDeck.Admin.Client).ErrorText(json, $get(raw)))
			continue
		}
		set entry = {"role":(node.role), "kind":(node.kind), "path":(node.path), "resources":(detail.Resources)}
		do entry.%Set("depth", node.depth, "number")
		do out.roles.%Push(entry)
		continue:'$isobject(detail.GrantedRoles)
		if node.depth >= ..#MAXDEPTH {
			if detail.GrantedRoles.%Size() > 0 {
				set truncated = 1
				do out.unread.%Push(node.role_": granted roles beyond depth "_..#MAXDEPTH)
			}
			continue
		}
		set granted = detail.GrantedRoles.%GetIterator()
		while granted.%GetNext(, .name) {
			continue:$data(visited(name))
			set path = ##class(%DynamicAbstractObject).%FromJSON(node.path.%ToJSON())
			do path.%Push(name)
			do queue.%Push({"role":(name), "kind":(node.kind), "path":(path), "depth":(node.depth + 1)})
		}
	}
	do out.%Set("truncated", truncated, "boolean")
	quit out
}

/// The chain to a role, without the role itself: "through A, B". "" when the role is direct.
ClassMethod ChainText(path As %DynamicArray) As %String
{
	quit:'$isobject(path) ""
	set text = ""
	for i=0:1:path.%Size()-2 { set text = text _ $select(text="":"", 1:", ") _ path.%Get(i) }
	quit text
}

/// The seeds of a user: direct roles as "role", escalation roles as "escalation".
ClassMethod SeedsForUser(user As %DynamicObject) As %DynamicArray
{
	set seeds = []
	for field = "Roles", "EscalationRoles" {
		continue:'$isobject(user.%Get(field))
		set iter = user.%Get(field).%GetIterator()
		while iter.%GetNext(, .role) {
			do seeds.%Push({"role":(role), "kind":($select(field="Roles":"role", 1:"escalation"))})
		}
	}
	quit seeds
}

}

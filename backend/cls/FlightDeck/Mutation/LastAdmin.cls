/// The last-administrator predicate (feature 003 spec FR-010 to FR-010c), evaluated on the server
/// against the state re-read immediately before writing.
/// <p>Counted: users that are enabled, not past their expiry date, and hold `%Admin_Secure:USE`
/// (directly or through the role graph) **or** have `%All` among their roles. `%All` is counted by
/// name, read from the user's own Roles: the official API reports no resources for it (probe finding
/// A), so nothing about what it grants is inferred. Delegated access and LDAP are not counted, and
/// the block message says so.
/// <p>Two modes. **complete**: every read the predicate needed succeeded, so a violation is an
/// affirmative block. **partial**: a read was refused or a cap was reached, so the portal neither
/// asserts nor denies — it reports the incomplete check and asks for the reinforced confirmation.
/// A baseline is required: the block happens only when the counted set was non-empty before the
/// change and is empty after it. An empty baseline means the predicate cannot see this instance's
/// administrative access at all, which is partial, not a block.
Class FlightDeck.Mutation.LastAdmin [ Abstract ]
{

Parameter PRIVILEGE = "%Admin_Secure";

Parameter SUPERROLE = "%All";

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/roles", "GET /v2/security/role", "GET /v2/security/role/owners", "GET /v2/security/user")
}

/// The evaluation for a mutation context, computed once and cached on the context.
/// Returns {"mode", "result", "unread", "before", "after"}.
ClassMethod Evaluate(ctx As %DynamicObject) As %DynamicObject
{
	if $isobject(ctx.check) quit ctx.check
	set unread = []
	set before = ..Holders({}, unread, .completeBefore)
	set overrides = ..Overrides(ctx)
	set after = ..Holders(overrides, unread, .completeAfter)
	set check = ..Decide(before.%Size(), after.%Size(), completeBefore && completeAfter, unread)
	set ctx.check = check
	quit check
}

/// The rule itself, as a pure decision over the two counts (spec FR-010 to FR-010-2). Separated so
/// the baseline and the incomplete cases are testable without staging an instance that has no
/// administrator at all.
ClassMethod Decide(before As %Integer, after As %Integer, complete As %Boolean, unread As %DynamicArray = "") As %DynamicObject
{
	set:'$isobject(unread) unread = []
	set check = {"unread":(unread)}
	do check.%Set("before", before, "number")
	do check.%Set("after", after, "number")
	if before = 0 {
		// No baseline: the predicate cannot see this instance's administrative access, so it does not
		// assert anything about what the change would leave (spec FR-010-1).
		set check.mode = "partial", check.result = "not-determined"
		do unread.%Push("no administrator was visible before the change: " _ ..#PRIVILEGE _ ":USE holders and " _ ..#SUPERROLE _ " members")
		quit check
	}
	if 'complete {
		set check.mode = "partial", check.result = "not-determined"
		quit check
	}
	set check.mode = "complete"
	set check.result = $select(after = 0:"would-remove-last", 1:"held")
	quit check
}

/// True only for an affirmative block: complete mode and an empty set after the change.
ClassMethod WouldRemoveLast(ctx As %DynamicObject) As %Boolean
{
	set check = ..Evaluate(ctx)
	quit (check.mode = "complete") && (check.result = "would-remove-last")
}

/// True when the check ran and could not assert: the caller asks for the reinforced confirmation.
ClassMethod Incomplete(ctx As %DynamicObject) As %Boolean
{
	set check = ..Evaluate(ctx)
	quit check.mode = "partial"
}

/// The message a block carries: what was counted, and what was not.
ClassMethod Message(ctx As %DynamicObject) As %String
{
	quit "This change would leave the instance with no administrator. It counted the enabled, unexpired users that hold "
		_ ..#PRIVILEGE _ ":USE or have " _ ..#SUPERROLE _ " among their roles. Access through delegated authentication or LDAP was not counted, because the official API does not report it."
}

/// The note an incomplete check carries, naming what could not be read.
ClassMethod Notice(ctx As %DynamicObject) As %String
{
	set check = ..Evaluate(ctx)
	quit:check.mode'="partial" ""
	quit "The last-administrator check was incomplete, so this change is not refused and is not declared safe: "
		_ ##class(FlightDeck.Domain.Links.RoleHolders).PathText(check.unread)
		_ ". Confirm only if you know another administrator remains."
}

/// The users counted as administrators, under the given overrides.
/// overrides: {"users":{name: object-or-null}, "roles":{name: object-or-null}, "resourceDeleted":name}
ClassMethod Holders(overrides As %DynamicObject, unread As %DynamicArray, Output complete As %Boolean) As %DynamicArray
{
	set complete = 1, holders = []
	kill counted
	set roles = ..AdminRoles(overrides, unread, .rolesComplete)
	set:'rolesComplete complete = 0
	// Candidates: the users behind each role that grants the privilege, plus the members of %All.
	set candidates = []
	kill seen
	set roleList = roles
	do roleList.%Push(..#SUPERROLE)
	set iter = roleList.%GetIterator()
	while iter.%GetNext(, .role) {
		set answer = ##class(FlightDeck.Domain.Links.RoleHolders).Users(role)
		if answer.truncated {
			set complete = 0
			set inner = answer.unread.%GetIterator()
			while inner.%GetNext(, .item) { do unread.%Push(item) }
		}
		set users = answer.users.%GetIterator()
		while users.%GetNext(, .user) {
			continue:$data(seen(user.name))
			set seen(user.name) = ""
			do candidates.%Push(user.name)
		}
	}
	// Users the change itself creates or edits are candidates too, even if no listing named them.
	if $isobject(overrides.users) {
		set iter = overrides.users.%GetIterator()
		while iter.%GetNext(.name) {
			continue:$data(seen(name))
			set seen(name) = ""
			do candidates.%Push(name)
		}
	}
	set iter = candidates.%GetIterator()
	while iter.%GetNext(, .name) {
		set user = ..UserObject(name, overrides, unread, .userComplete)
		set:'userComplete complete = 0
		continue:'$isobject(user)
		continue:''user.Enabled=0
		continue:##class(FlightDeck.Domain.Facts).Expired(user.ExpirationDate)
		continue:'..CountsAsAdministrator(user, roles)
		do holders.%Push(name)
	}
	quit holders
}

/// True when the user's own roles include %All or any role that grants the privilege.
ClassMethod CountsAsAdministrator(user As %DynamicObject, adminRoles As %DynamicArray) As %Boolean
{
	kill held
	for field = "Roles", "EscalationRoles" {
		continue:'$isobject(user.%Get(field))
		set iter = user.%Get(field).%GetIterator()
		while iter.%GetNext(, .role) { continue:role=""  set held(role) = "" }
	}
	quit:$data(held(..#SUPERROLE)) 1
	// A role the user holds may grant the privilege directly or through the roles it inherits;
	// adminRoles already carries that closure.
	set iter = adminRoles.%GetIterator(), found = 0
	while iter.%GetNext(, .role) {
		continue:role=""
		if $data(held(role)) { set found = 1 quit }
	}
	quit found
}

/// Roles that grant the privilege, directly or through GrantedRoles, under the overrides.
ClassMethod AdminRoles(overrides As %DynamicObject, unread As %DynamicArray, Output complete As %Boolean) As %DynamicArray
{
	set complete = 1, out = []
	if $isobject(overrides) && (overrides.resourceDeleted = ..#PRIVILEGE) quit out
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/security/roles", {"maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 {
		set complete = 0
		do unread.%Push("the role list (" _ ##class(FlightDeck.Admin.Client).ErrorText($get(json), $get(raw)) _ ")")
		quit out
	}
	kill grants
	set names = [], iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .item) { do names.%Push(item.Name) }
	set iter = names.%GetIterator()
	while iter.%GetNext(, .name) {
		set role = ..RoleObject(name, overrides, unread, .roleComplete)
		set:'roleComplete complete = 0
		continue:'$isobject(role)
		set grants(name) = ..Direct(role)
		set grants(name, "granted") = $select($isobject(role.GrantedRoles):role.GrantedRoles.%ToJSON(), 1:"[]")
	}
	// Transitive closure: a role grants the privilege when it grants it directly or inherits a role
	// that does.
	set changed = 1
	while changed {
		set changed = 0, name = ""
		for {
			set name = $order(grants(name)) quit:name=""
			continue:grants(name)
			set granted = ##class(%DynamicAbstractObject).%FromJSON(grants(name, "granted"))
			set inner = granted.%GetIterator()
			while inner.%GetNext(, .child) {
				if $get(grants(child)) { set grants(name) = 1, changed = 1 quit }
			}
		}
	}
	set name = ""
	for { set name = $order(grants(name)) quit:name=""  do:grants(name) out.%Push(name) }
	quit out
}

/// True when the role object itself grants the privilege with Use.
ClassMethod Direct(role As %DynamicObject) As %Boolean
{
	quit:'$isobject(role.Resources) 0
	set iter = role.Resources.%GetIterator()
	while iter.%GetNext(, .grant) {
		if grant.Name = ..#PRIVILEGE, $zconvert(grant.Permissions, "U") [ "U" quit
	}
	quit $isobject($get(grant)) && (grant.Name = ..#PRIVILEGE) && ($zconvert(grant.Permissions, "U") [ "U")
}

/// A role object under the overrides: the proposed one, "" when the change deletes it, or the read.
ClassMethod RoleObject(name As %String, overrides As %DynamicObject, unread As %DynamicArray, Output complete As %Boolean) As %DynamicObject
{
	set complete = 1
	if $isobject(overrides) && $isobject(overrides.roles) && overrides.roles.%IsDefined(name) quit overrides.roles.%Get(name)
	set role = ##class(FlightDeck.Domain.Links.RoleGraph).Detail(name, .status, .json, .raw)
	if status '= 200 {
		set complete = 0
		do unread.%Push("role " _ name _ " (" _ ##class(FlightDeck.Admin.Client).ErrorText($get(json), $get(raw)) _ ")")
		quit ""
	}
	quit role
}

/// A user object under the overrides, cached per request.
ClassMethod UserObject(name As %String, overrides As %DynamicObject, unread As %DynamicArray, Output complete As %Boolean) As %DynamicObject
{
	set complete = 1
	if $isobject(overrides) && $isobject(overrides.users) && overrides.users.%IsDefined(name) quit overrides.users.%Get(name)
	if $data(%FlightDeckUserDetail(name)) {
		set cached = %FlightDeckUserDetail(name)
		quit $select(cached="":"", 1:##class(%DynamicAbstractObject).%FromJSON(cached))
	}
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/security/user", {"name":(name)}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 {
		set complete = 0
		do unread.%Push("user " _ name _ " (" _ ##class(FlightDeck.Admin.Client).ErrorText($get(json), $get(raw)) _ ")")
		set %FlightDeckUserDetail(name) = ""
		quit ""
	}
	set %FlightDeckUserDetail(name) = json.result.%ToJSON()
	quit json.result
}

/// The proposed change, as overrides the predicate applies in memory before testing the set.
ClassMethod Overrides(ctx As %DynamicObject) As %DynamicObject
{
	set overrides = {"users":{}, "roles":{}, "resourceDeleted":""}
	set target = ctx.keys.name
	set path = ##class(FlightDeck.Domain.Entity).Path(ctx.operationId)
	if path = "/v2/security/user" {
		if ctx.kind = "delete" { do overrides.users.%Set(target, "", "null") quit overrides }
		do overrides.users.%Set(target, ##class(FlightDeck.Mutation.Service).Proposed(ctx))
		quit overrides
	}
	if path = "/v2/security/role" {
		if ctx.kind = "delete" { do overrides.roles.%Set(target, "", "null") quit overrides }
		do overrides.roles.%Set(target, ##class(FlightDeck.Mutation.Service).Proposed(ctx))
		quit overrides
	}
	if (path = "/v2/security/resource") && (ctx.kind = "delete") set overrides.resourceDeleted = target
	quit overrides
}

}

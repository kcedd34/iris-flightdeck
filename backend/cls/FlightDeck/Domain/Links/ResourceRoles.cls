/// Link provider "resource-roles": the roles that grant the entity's resource, with the permission
/// and, for inherited grants, the granted role it comes through (feature 002 research R6).
/// <p>Composed from GET /v2/security/roles and GET /v2/security/role. %All grants every resource.
Class FlightDeck.Domain.Links.ResourceRoles [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/roles", "GET /v2/security/role")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	// The entity either names a resource (a web application, a privileged routine application) or is
	// one (the permissions domain, feature 003).
	set resource = $select(entity.entityType = "resource":entity.keys.name, 1:entity.object.Resource)
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("resource-roles", "roles grant this resource", "in")
	if resource = "" {
		set group.label = "Not restricted by a resource"
		set group.count = 0
		quit group
	}
	set roles = ..Granting(resource, .failure)
	if $isobject(failure) quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, failure.operationId, failure.status, failure.json, failure.raw)
	set iter = roles.%GetIterator()
	while iter.%GetNext(, .grant) {
		do group.items.%Push(##class(FlightDeck.Domain.LinkProviders).Item("role", "permissions", grant.role, grant.detail))
	}
	set group.count = roles.%Size()
	quit group
}

/// Roles granting a resource: [{role, permissions, detail}]. failure is set when a read failed.
ClassMethod Granting(resource As %String, Output failure As %DynamicObject) As %DynamicArray
{
	set failure = ""
	set map = ..RoleMap(.failure)
	if $isobject(failure) quit []
	// Direct grants first, then inherited ones, then %All: the roles an administrator configured
	// matter more than the super-user role that grants everything.
	set iter = map.%GetIterator()
	while iter.%GetNext(.role) {
		kill visited
		set perms = ..Permissions(map, role, resource, .visited, .via)
		continue:perms=""
		set rank = $select(role="%All":3, via'="":2, 1:1)
		set sorted(rank, role) = $listbuild(perms, $select(role="%All":"all resources", via'="":perms_" through "_via, 1:perms))
	}
	set out = [], rank = ""
	for {
		set rank = $order(sorted(rank))
		quit:rank=""
		set role = ""
		for {
			set role = $order(sorted(rank, role))
			quit:role=""
			do out.%Push({"role":(role), "permissions":($list(sorted(rank, role), 1)), "detail":($list(sorted(rank, role), 2))})
		}
	}
	quit out
}

/// {roleName: {resources: {name: perms}, granted: [..]}} for every role, cached for 30 s.
ClassMethod RoleMap(Output failure As %DynamicObject) As %DynamicObject
{
	set failure = ""
	if ##class(FlightDeck.Domain.LinkCache).Get("role-map", .map) quit map
	set list = ##class(FlightDeck.Admin.Client).Get("/v2/security/roles", {"maxRows":1000}, .status, .raw)
	if status '= 200 {
		set failure = {"operationId":"GET /v2/security/roles", "status":(status), "json":"", "raw":(raw)}
		quit {}
	}
	set map = {}
	set iter = list.%GetIterator()
	while iter.%GetNext(, .summary) {
		set role = ##class(FlightDeck.Admin.Client).Get("/v2/security/role", {"name":(summary.Name)}, .status, .raw)
		if status '= 200 {
			set failure = {"operationId":"GET /v2/security/role", "status":(status), "json":"", "raw":(raw)}
			quit
		}
		set resources = {}
		set r = $select($isobject(role.Resources):role.Resources.%GetIterator(), 1:"")
		while $isobject(r) && r.%GetNext(, .grant) { do resources.%Set(grant.Name, grant.Permissions) }
		do map.%Set(summary.Name, {"resources":(resources), "granted":($select($isobject(role.GrantedRoles):role.GrantedRoles, 1:[]))})
	}
	if $isobject(failure) quit {}
	do ##class(FlightDeck.Domain.LinkCache).Set("role-map", map)
	quit map
}

/// Permissions a role holds on a resource, directly or through granted roles (cycles guarded).
ClassMethod Permissions(map As %DynamicObject, role As %String, resource As %String, ByRef visited, Output via As %String) As %String
{
	set via = ""
	if role = "%All" quit "RWU"
	quit:$data(visited(role)) ""
	set visited(role) = ""
	set entry = map.%Get(role)
	quit:'$isobject(entry) ""
	set direct = entry.resources.%Get(resource)
	if direct '= "" quit direct
	set iter = entry.granted.%GetIterator(), found = ""
	while iter.%GetNext(, .granted) {
		set found = ..Permissions(map, granted, resource, .visited, .innerVia)
		if found '= "" set via = granted quit
	}
	quit found
}

}

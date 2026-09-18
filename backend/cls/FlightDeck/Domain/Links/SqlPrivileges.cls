/// Link provider "sql-privileges" (feature 003 spec FR-006, FR-006b; probe P4): the SQL privileges a
/// user or role holds in one namespace.
/// <p>The official listings answer only for a given grantee and namespace, so this provider declares
/// the namespace as a parameter and answers nothing until it has one (contract ui-pattern-delta D2).
/// <p>Provenance is the API's own: `GrantedVia` already resolves the role chain (a privilege granted
/// to a role three levels above a user is reported as "Role:<role>"), so FlightDeck renders it and
/// computes no second answer.
Class FlightDeck.Domain.Links.SqlPrivileges [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/sql-privileges", "GET /v2/security/sql-admin-privileges", "GET /v2/namespaces")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("sql-privileges", "SQL privileges in this namespace", "out")
	set namespace = $select($isobject(params):params.%Get("namespace"), 1:"")
	set values = ..Namespaces(.reason)
	if namespace = "" {
		set parameters = [(##class(FlightDeck.Domain.LinkProviders).Parameter("namespace", 1, values))]
		quit ##class(FlightDeck.Domain.LinkProviders).NeedsParameter(group, parameters, reason)
	}
	set group.parameters = [(##class(FlightDeck.Domain.LinkProviders).Parameter("namespace", 1, values, namespace))]
	set grantee = entity.keys.name
	set unread = []
	do ..Collect(group, unread, "GET /v2/security/sql-privileges", grantee, namespace, "object")
	do ..Collect(group, unread, "GET /v2/security/sql-admin-privileges", grantee, namespace, "admin")
	set group.count = group.items.%Size()
	if unread.%Size() > 0 {
		set group.state = "undetermined"
		set group.reason = "Not read: " _ ##class(FlightDeck.Domain.Links.RoleHolders).PathText(unread)
	}
	quit group
}

/// The namespaces the session may list, for the parameter's choices. Empty when it may not, and the
/// reason says so: the control then accepts a typed value.
ClassMethod Namespaces(Output reason As %String) As %DynamicArray
{
	set reason = "", values = []
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/namespaces", {"maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 {
		set reason = "Choose a namespace. The list could not be read: " _ ##class(FlightDeck.Admin.Client).ErrorText($get(json), $get(raw))
		quit values
	}
	// The current namespace first, so a panel opened by name answers at once. "%ALL" is the
	// platform's wildcard, not a namespace a privilege can be listed for, so it is not offered.
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	set others = []
	while iter.%GetNext(, .item) {
		set name = $select($isobject(item):item.Name, 1:item)
		continue:name="%ALL"
		if name = $namespace { do values.%Push(name) } else { do others.%Push(name) }
	}
	set iter = others.%GetIterator()
	while iter.%GetNext(, .name) { do values.%Push(name) }
	set reason = "Choose a namespace: the official listing answers per namespace and grantee."
	quit values
}

/// One official listing, rendered with the provenance the API reports.
ClassMethod Collect(group As %DynamicObject, unread As %DynamicArray, operationId As %String, grantee As %String, namespace As %String, kind As %String)
{
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", ##class(FlightDeck.Domain.Entity).Path(operationId), {"grantee":(grantee), "namespace":(namespace), "maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 {
		do unread.%Push(kind _ " privileges (" _ ##class(FlightDeck.Admin.Client).ErrorText($get(json), $get(raw)) _ ")")
		quit
	}
	set rows = $select($isobject(json) && $isobject(json.result):json.result, 1:[])
	set iter = rows.%GetIterator()
	while iter.%GetNext(, .row) {
		if kind = "admin" {
			set name = row.Privilege
		} else {
			// The listing returns Object and Action where its own schema declares Name and Privilege
			// (verification/README.md); either is accepted, and neither is rewritten.
			set object = $select(row.%IsDefined("Object"):row.Object, 1:row.Name)
			set action = $select(row.%IsDefined("Action"):row.Action, 1:row.Privilege)
			set name = action _ " on " _ object
		}
		set detail = row.GrantedVia _ $select(''row.GrantOption:", with grant option", 1:"")
		do group.items.%Push({"entityType":"sql-privilege", "domain":"permissions", "displayName":(name), "keys":{}, "detail":(detail)})
	}
}

}

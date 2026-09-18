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
	quit $listbuild("GET /v2/security/sql-privileges", "GET /v2/security/sql-admin-privileges", "GET /v2/security/sql-column-privileges", "GET /v2/namespaces")
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
	// Column privileges are the third kind the platform records, and the finest: INSERT on one column
	// of one table. They are read per object, so they are collected for the objects the two listings
	// above already named — a privilege on a column nobody can reach is not a privilege in practice.
	do ..Columns(group, unread, grantee, namespace)
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
/// Column privileges for the objects this grantee already holds an object privilege on.
ClassMethod Columns(group As %DynamicObject, unread As %DynamicArray, grantee As %String, namespace As %String)
{
	set objects = "", iter = group.items.%GetIterator()
	while iter.%GetNext(, .item) {
		set name = item.displayName
		continue:'(name [ " on ")
		set object = $piece(name, " on ", 2, *)
		continue:object=""
		set objects(object) = ""
	}
	set object = "", read = 0
	for {
		set object = $order(objects(object))
		quit:object=""
		// A grantee with privileges on very many objects would otherwise turn one panel into hundreds
		// of requests; the cap is declared and what was not read is stated.
		if read >= ..#MAXCOLUMNOBJECTS {
			do unread.%Push("column privileges beyond the first " _ ..#MAXCOLUMNOBJECTS _ " objects")
			quit
		}
		set read = read + 1
		set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/security/sql-column-privileges", {"grantee":(grantee), "namespace":(namespace), "object":(object), "maxRows":1000}, "", .status, .json, .raw)
		if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
		if status '= 200 {
			do unread.%Push("column privileges on " _ object _ " (" _ ##class(FlightDeck.Admin.Client).ErrorText($get(json), $get(raw)) _ ")")
			continue
		}
		set rows = $select($isobject(json) && $isobject(json.result):json.result, 1:[])
		set cols = rows.%GetIterator()
		while cols.%GetNext(, .row) {
			set action = $select(row.%IsDefined("Action"):row.Action, row.%IsDefined("Privilege"):row.Privilege, 1:"")
			set column = $select(row.%IsDefined("Column"):row.Column, row.%IsDefined("Name"):row.Name, 1:"")
			set detail = $select(row.%IsDefined("GrantedVia"):row.GrantedVia, 1:"") _ $select(''row.GrantOption:", with grant option", 1:"")
			do group.items.%Push({"entityType":"sql-privilege", "domain":"permissions", "displayName":(action _ " on " _ object _ "." _ column), "keys":{}, "detail":(detail)})
		}
	}
}

/// How many objects' column privileges one panel reads. Declared, and what it skipped is stated.
Parameter MAXCOLUMNOBJECTS = 10;

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

/// Native provider for namespace and mapping READS, used only on the v1 dialect (IRIS 2026.1), whose
/// SysAdmin API has no namespace operations. Constitution I v2.1.0 gap "Namespace and mapping reads,
/// v1 dialect only"; on v2 the official /v2/namespace operations stay in use.
/// <p>Reached only through FlightDeck.Admin.Client (the v1 dialect table names this class), so
/// callers never see a dialect. Each operation mirrors the IRIS 2026.2 handler
/// (%Api.Admin.Endpoints.Namespace.*): the same Config query or Exists call, the same column
/// mapping and exclusions, the same status codes, and the official response envelope. Responses are
/// verified equal to the official API on IRIS 2026.2 (FlightDeck.Test.NativeNamespaces).
/// <p><b>Writes are never native</b> (Constitution I): a native write would copy platform side
/// effects FlightDeck does not control.
Class FlightDeck.Native.Namespaces [ Abstract ]
{

/// Answers one v2 read operation with the official envelope. Outputs the HTTP status, the parsed
/// body and its JSON text, like FlightDeck.Admin.Client.Call.
ClassMethod Handle(operationId As %String, query As %DynamicObject = "", Output status As %Integer, Output result As %DynamicObject, Output raw As %String) As %Status
{
	set status = 200, payload = {}, sc = $$$OK
	// The privilege the v2 operation declares (Constitution III), refused like the API: 403, no errors.
	if '##class(FlightDeck.Capability.Map).CurrentUserMay(operationId) {
		set status = 403
		do ..Envelope({}, $$$OK, .result, .raw)
		quit $$$OK
	}
	try {
		new $namespace
		set $namespace = "%SYS"
		if operationId = "GET /v2/namespaces" {
			set filters = $select(..Param(query, "filter", .filter):$listbuild(filter), 1:"")
			set payload = ..RunQuery("Config.Namespaces", "ListFilter", filters, query, $listbuild("Namespace:Name", "System Globals:SysGlobals", "System Routines:SysRoutines", "Temp Storage:TempGlobals"), "", "", .sc)
		} elseif operationId = "GET /v2/namespace" {
			set name = ..Required(query, "name", .status, .sc)
			if status = 200 {
				if '##class(Config.Namespaces).Exists(name, .obj, .sc) {
					set status = 404
				} else {
					set payload = {}
					set payload.Globals = obj.Globals
					set payload.Routines = obj.Routines
					set payload.TempGlobals = obj.TempGlobals
				}
			}
		} elseif $piece(operationId, "/", 4) [ "-mapping" {
			set kind = $piece($piece(operationId, "/", 4), "-", 1)
			set configClass = $case(kind, "global":"Config.MapGlobals", "package":"Config.MapPackages", :"Config.MapRoutines")
			set list = ($extract(operationId, *) = "s")
			// ValidateQueryParams order in the official handler: name (items only), then namespace.
			if 'list set name = ..Required(query, "name", .status, .sc)
			if status = 200 set namespace = ..Required(query, "namespace", .status, .sc)
			if (status = 200) && list {
				set filters = $select(..Param(query, "names", .names):$listbuild(namespace, names), 1:$listbuild(namespace))
				set exclude = $case(kind, "global":"Global", "package":"Package", :"Routine")
				set payload = ..RunQuery(configClass, "List", filters, query, "", exclude, $select(kind="global":"Collation", 1:""), .sc)
			} elseif status = 200 {
				if '$classmethod(configClass, "Exists", namespace, name, .obj, .sc) {
					set status = 404
				} else {
					set payload = {}
					if kind = "global" set payload.Collation = obj.Collation
					set payload.Database = obj.Database
					if kind = "global" set payload.LockDatabase = obj.LockDatabase
				}
			}
		} else {
			set status = 501
			set sc = $$$ERROR($$$GeneralError, "No native provider for "_operationId)
		}
	} catch ex {
		set sc = ex.AsStatus()
	}
	if $$$ISERR(sc), status < 400 set status = 500
	if status >= 400 set payload = {}
	do ..Envelope(payload, sc, .result, .raw)
	quit $$$OK
}

/// %Api.Admin.Util.ClassQuery.RunQuery semantics: the class query's columns, renamed ("From:To")
/// or excluded, typed by client type, at most maxRows rows (default 1000).
ClassMethod RunQuery(queryClass As %String, queryName As %String, filters As %List, query As %DynamicObject, renames As %List, exclude As %String, numberColumns As %String, Output sc As %Status) As %DynamicArray
{
	set sc = $$$OK, rows = []
	set statement = ##class(%SQL.Statement).%New()
	set sc = statement.%PrepareClassQuery(queryClass, queryName, 2)
	quit:$$$ISERR(sc) rows
	set args = $listlength(filters)
	for i=1:1:args { set args(i) = $listget(filters, i) }
	set resultSet = $select(args:statement.%Execute(args...), 1:statement.%Execute())
	set maxRows = $select(..Param(query, "maxRows", .value):value, 1:1000)
	set columns = resultSet.%GetMetadata().columns, count = 0
	for c=1:1:columns.Count() {
		set column = columns.GetAt(c), name = column.colName
		continue:name=exclude
		set jsonName = name, ptr = 0
		while $listnext(renames, ptr, rename) { set:$piece(rename, ":", 1)=name jsonName = $piece(rename, ":", 2) }
		set type = $case(column.clientType, 3:"number", 5:"number", 14:"number", 15:"number", 16:"boolean", 18:"number", 21:"number", :"string")
		set:(","_numberColumns_",")[(","_jsonName_",") type = "number"
		set count = count + 1, map(count) = $listbuild(c, jsonName, type)
	}
	set n = 0
	while resultSet.%Next(.sc) {
		quit:$$$ISERR(sc)
		set n = n + 1, row = {}
		for i=1:1:count {
			set $listbuild(c, jsonName, type) = map(i)
			set value = resultSet.%GetData(c)
			try {
				do row.%Set(jsonName, value, type)
			} catch {
				do row.%Set(jsonName, value, "string")
			}
		}
		do rows.%Push(row)
		quit:(maxRows>0)&&(n>=maxRows)
	}
	quit rows
}

ClassMethod Param(query As %DynamicObject, name As %String, Output value As %String) As %Boolean
{
	set value = ""
	if '$isobject(query) || 'query.%IsDefined(name) quit 0
	set value = query.%Get(name)
	quit 1
}

/// A missing required parameter answers 400 with ERROR #40300, as the official handler does.
ClassMethod Required(query As %DynamicObject, name As %String, ByRef status As %Integer, ByRef sc As %Status) As %String
{
	if ..Param(query, name, .value) quit value
	set status = 400, sc = $$$ERROR(40300, name)
	quit ""
}

/// The official envelope: status.errors from the %Status (error, code, domain, params), summary,
/// console and result.
ClassMethod Envelope(payload As %DynamicAbstractObject, sc As %Status, Output result As %DynamicObject, Output raw As %String)
{
	set errors = [], summary = ""
	if $$$ISERR(sc) {
		do $system.Status.DecomposeStatus(sc, .parts)
		for i=1:1:$get(parts) {
			set error = {"error":(parts(i)), "code":(+parts(i, "code")), "domain":($get(parts(i, "domain"))), "params":[]}
			for p=1:1:$get(parts(i, "param")) { do error.params.%Push(parts(i, "param", p)) }
			do errors.%Push(error)
		}
		set summary = $zconvert($system.Status.GetErrorText(sc), "O", "HTML")
	}
	set result = {"status":{"errors":(errors), "summary":(summary)}, "console":[], "result":(payload)}
	set raw = result.%ToJSON()
}

}

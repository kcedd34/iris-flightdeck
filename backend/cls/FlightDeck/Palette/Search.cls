/// Generic entity search for the command palette (FR-021, FR-022, FR-024, research R15).
/// <p>Searchable operations are derived from FlightDeck.Capability.Spec: parameterless GET list
/// operations whose summary starts with "View a list of" or "List", minus volatile runtime lists.
/// Whether the user may call each one comes from the derived capability map (Constitution III);
/// the table below only supplies display labels and the screen each entity type belongs to.
/// <p>The whole search never fails: groups report forbidden, timeout or error on their own, and the
/// response is marked degraded.
Class FlightDeck.Palette.Search [ Abstract ]
{

/// Total time budget for one search, in milliseconds.
Parameter DEADLINE = 1500;

/// Runtime lists that change second to second; not useful as palette entities.
Parameter VOLATILE = "/v2/processes,/v2/locks,/v2/web-sessions,/v2/async-results,/v2/task/history,/v2/task/upcoming,/v2/security/encryption/keys,/v2/security/encryption/data-element-keys,/v2/ecp/application-server-ssl-connections,/v2/ecp/application-servers";

/// path -> $listbuild(entity type label, section id, name keys to try in order)
ClassMethod Presentation(path As %String) As %List
{
	quit $case(path,
		"/v2/web-apps":$listbuild("Web application", "web-applications", "Name"),
		"/v2/web-app/pct-accesses":$listbuild("Percent class access", "percent-class-access", "Name,Namespace"),
		"/v2/security/users":$listbuild("User", "users", "Name"),
		"/v2/security/roles":$listbuild("Role", "roles", "Name"),
		"/v2/security/resources":$listbuild("Resource", "resources", "Name"),
		"/v2/security/services":$listbuild("Service", "services", "Name"),
		"/v2/security/privileged-routines":$listbuild("Privileged routine", "privileged-routines", "Name"),
		"/v2/security/ssl-configurations":$listbuild("TLS configuration", "tls", "Name"),
		"/v2/security/x509-credentials":$listbuild("X.509 credential", "x509", "Alias,Name"),
		"/v2/security/oauth2/client/server-definitions":$listbuild("OAuth 2.0 server definition", "oauth2", "IssuerEndpoint,Name"),
		"/v2/security/oauth2/resource-servers":$listbuild("OAuth 2.0 resource server", "oauth2", "Name"),
		"/v2/security/oauth2/server/clients":$listbuild("OAuth 2.0 client", "oauth2", "Name,ClientId"),
		"/v2/security/ldap/configurations":$listbuild("LDAP configuration", "ldap", "Name"),
		"/v2/security/mft/connections":$listbuild("MFT connection", "mft", "Name"),
		"/v2/security/superservers":$listbuild("Superserver", "superservers", "Port,Name"),
		"/v2/wallet/collections":$listbuild("Wallet collection", "wallet", "Name"),
		"/v2/tasks":$listbuild("Task", "tasks", "Name"),
		"/v2/wqm-categories":$listbuild("Work queue category", "work-queue-categories", "Name"),
		"/v2/namespaces":$listbuild("Namespace", "namespaces", "Name"),
		"/v2/databases":$listbuild("Database", "databases", "Name"),
		"/v2/database-dirs":$listbuild("Database directory", "databases", "Directory"),
		"/v2/devices":$listbuild("Device", "devices", "Name"),
		"/v2/device/subtypes":$listbuild("Device subtype", "devices", "Name"),
		"/v2/doc-dbs":$listbuild("DocDB application", "docdb", "Name"),
		"/v2/ecp/data-servers":$listbuild("ECP data server", "ecp", "Name"),
		"/v2/ext-lang-servers":$listbuild("External language server", "external-language-servers", "Name"),
		"/v2/fs-access-purposes":$listbuild("File system access purpose", "file-system-access", "Name,Purpose"),
		"/v2/license/servers":$listbuild("License server", "license", "Name"),
		"/v2/journal/files":$listbuild("Journal file", "stream", "Name,File"),
		"/v2/security/audit/events":$listbuild("Audit event", "stream", "Name,Source"),
		:"")
}

/// The searchable operations, in rail order, as $list of capability entries' operationIds.
ClassMethod Searchable() As %DynamicArray
{
	set out = []
	set iter = ##class(FlightDeck.Capability.Spec).Operations().%GetIterator()
	while iter.%GetNext(, .op) {
		continue:op.method'="GET"
		continue:op.domain="shell"
		continue:op.requiredParams.%Size()>0
		continue:'((op.summary?1"View a list of".E)||(op.summary?1"List ".E))
		continue:$listfind($listfromstring(..#VOLATILE), op.path)
		continue:..Presentation(op.path)=""
		do out.%Push(op)
	}
	quit out
}

ClassMethod Run(q As %String, domain As %String = "", limit As %Integer = 5) As %DynamicObject
{
	set started = $zhorolog
	set info = ##class(FlightDeck.Admin.Client).Get("/info", , .status, .raw)
	set privileges = ##class(FlightDeck.Capability.Map).NormalizePrivileges($select($isobject(info):info.privileges, 1:""))
	set needle = ..Normalize(q)
	// The API's own filter is literal; use it only when separators cannot differ.
	set literal = ($translate(q, "_- /.", "") = q)
	set groups = [], degraded = 0, reason = "", totalResults = 0
	set order = $listbuild("web-apps", "permissions", "security", "tasks", "system", "logs")
	set ops = ..Searchable()
	for d=1:1:$listlength(order) {
		set dom = $list(order, d)
		continue:(domain'="")&&(domain'=dom)
		set iter = ops.%GetIterator()
		while iter.%GetNext(, .op) {
			continue:op.domain'=dom
			set pres = ..Presentation(op.path)
			set group = {"domain":(dom), "entityType":($list(pres, 1)), "state":"ok", "results":[]}
			do group.%Set("reason", "", "null")
			do group.%Set("total", "", "null")
			// An entity type the instance does not offer (v1 dialect) is not searched and does not
			// degrade the search: it is reported with the version reason.
			if '##class(FlightDeck.Admin.Client).Has(op.operationId) {
				set group.state = "unavailable"
				set group.reason = ##class(FlightDeck.Admin.Client).UnavailableReason(op.operationId)
				do groups.%Push(group)
				continue
			}
			if '##class(FlightDeck.Capability.Map).Allowed(op.requires, privileges) {
				set group.state = "forbidden"
				set group.reason = ##class(FlightDeck.API.Response).RequiresMessage(op.requires)
				do groups.%Push(group)
				continue
			}
			if ($zhorolog - started) * 1000 > ..#DEADLINE {
				set group.state = "timeout", group.reason = "Did not respond in time.", degraded = 1
				do groups.%Push(group)
				continue
			}
			set useFilter = op.hasFilter && literal
			set query = {"maxRows":($select(useFilter:limit * 4, 1:1000))}
			if useFilter set query.filter = q
			set sc = ##class(FlightDeck.Admin.Client).Call("GET", op.path, query, , .status, .json, .raw)
			set rows = $select($$$ISOK(sc)&&$isobject(json):json.result, 1:"")
			if (status '= 200) || '$isobject(rows) || (rows.%ClassName(1) '= "%Library.DynamicArray") {
				set group.state = $select(status=403:"forbidden", 1:"error")
				set group.reason = $select($$$ISERR(sc):$system.Status.GetErrorText(sc), 1:##class(FlightDeck.Admin.Client).ErrorText(json, raw))
				if status '= 403 set degraded = 1
				do groups.%Push(group)
				continue
			}
			set matches = ..Match(rows, needle, $list(pres, 3))
			set total = matches.%Size()
			continue:total=0
			set group.total = total
			set totalResults = totalResults + total
			for i=0:1:$select(total<limit:total, 1:limit)-1 {
				set m = matches.%Get(i)
				do group.results.%Push({
					"kind": "entity", "domain": (dom), "entityType": ($list(pres, 1)),
					"name": (m.name), "context": (..Context(m.row, $list(pres, 1))),
					"sourceOperationId": (op.operationId),
					"target": {"route": ("/"_dom_"/"_$list(pres, 2)), "inspect": {"entityType": ($list(pres, 1)), "name": (m.name)}}
				})
			}
			do groups.%Push(group)
		}
	}
	if degraded set reason = "Some domains did not respond in time or returned an error."
	set out = {"groups":(groups), "totalResults":(totalResults)}
	do out.%Set("degraded", degraded, "boolean")
	do out.%Set("reason", reason, $select(reason="":"null", 1:"string"))
	quit out
}

/// Ranks rows whose name contains the needle: exact, then prefix, then substring.
ClassMethod Match(rows As %DynamicArray, needle As %String, nameKeys As %String) As %DynamicArray
{
	set ranked = ""
	set iter = rows.%GetIterator()
	while iter.%GetNext(.index, .row) {
		continue:'$isobject(row)
		set name = ""
		for k=1:1:$length(nameKeys, ",") {
			set name = row.%Get($piece(nameKeys, ",", k))
			quit:name'=""
		}
		continue:name=""
		set lower = ..Normalize(name)
		continue:lower'[needle
		set rank = $select(lower=needle:0, $extract(lower, 1, $length(needle))=needle:1, 1:2)
		set ranked(rank, lower, $increment(ranked)) = $listbuild(name, index)
	}
	set out = []
	set rank = ""
	for { set rank = $order(ranked(rank)) quit:rank=""
		set key = ""
		for { set key = $order(ranked(rank, key)) quit:key=""
			set n = ""
			for { set n = $order(ranked(rank, key, n), 1, item) quit:n=""
				do out.%Push({"name":($list(item, 1)), "row":(rows.%Get($list(item, 2)))})
			}
		}
	}
	quit out
}

/// Lower case without separators, so "FD_Demo", "fd-demo" and "FD Demo" all match each other.
ClassMethod Normalize(text As %String) As %String
{
	quit $translate($zconvert(text, "L"), "_- /.", "")
}

/// Short disambiguating context: namespace when the row has one, otherwise the entity type.
ClassMethod Context(row As %DynamicObject, entityType As %String) As %String
{
	for key = "Namespace", "NameSpace", "Nspace" {
		set value = row.%Get(key)
		if value '= "" quit
	}
	quit $select($get(value)'="":entityType_" · "_value, 1:entityType)
}

}

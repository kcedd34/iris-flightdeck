/// The interoperability event log (feature 005 research R4).
/// <p>It is SQL, and it is per namespace: Ens_Util.Log exists in each interoperability-enabled
/// namespace. This source reads <b>every</b> such namespace up to a declared cap, and names both the
/// namespaces it read and the ones the cap or a refusal left out — the same rule the column
/// privileges panel and the certificate validity reads already use (spec FR-011a).
Class FlightDeck.Logs.Sources.Interop [ Abstract ]
{

Parameter SOURCE = "interop";

/// How many namespaces one page reads. Declared, and what it skipped is stated.
Parameter MAXNAMESPACES = 10;

/// The namespaces where interoperability is enabled, which is where the log exists.
ClassMethod Namespaces(Output reason As %String) As %DynamicArray
{
	set reason = "", out = []
	set sc = ##class(%SYS.Namespace).ListAll(.list)
	if $$$ISERR(sc) {
		set reason = $system.Status.GetErrorText(sc)
		quit out
	}
	set ns = ""
	for {
		set ns = $order(list(ns))
		quit:ns=""
		continue:ns="%SYS"
		set enabled = 0
		try { set enabled = ##class(%Library.EnsembleMgr).IsEnsembleNamespace(ns) } catch {}
		do:enabled out.%Push(ns)
	}
	quit out
}

ClassMethod Available(Output reason As %String) As %Boolean
{
	set reason = ""
	set namespaces = ..Namespaces(.listReason)
	if namespaces.%Size() = 0 {
		set reason = $select(listReason'="":listReason, 1:"No namespace on this instance has interoperability enabled, so there is no interoperability event log to read.")
		quit 0
	}
	quit 1
}

ClassMethod Page(query As %DynamicObject) As %DynamicObject
{
	set page = ##class(FlightDeck.Logs.Source).NewPage(..#SOURCE)
	set namespaces = ..Namespaces(.listReason)
	if namespaces.%Size() = 0 {
		quit ##class(FlightDeck.Logs.Source).Unavailable(page, $select(listReason'="":listReason, 1:"No namespace on this instance has interoperability enabled, so there is no interoperability event log to read."))
	}
	set limit = +$select($isobject(query) && (query.limit '= ""):query.limit, 1:100)
	set perNamespace = $select(limit\namespaces.%Size()>10:limit\namespaces.%Size(), 1:10)
	set read = [], iter = namespaces.%GetIterator(), n = 0
	set here = $namespace
	while iter.%GetNext(, .ns) {
		set n = n + 1
		if n > ..#MAXNAMESPACES {
			do page.unread.%Push("namespaces beyond the first " _ ..#MAXNAMESPACES _ " (" _ ns _ " and later)")
			quit
		}
		do ..ReadNamespace(page, ns, perNamespace, read)
	}
	if $namespace '= here znspace here
	set page.namespaces = read
	set page.read = page.events.%Size()
	quit page
}

/// One namespace's newest rows. A namespace the session may not read is named as unread, never
/// skipped in silence.
ClassMethod ReadNamespace(page As %DynamicObject, ns As %String, limit As %Integer, read As %DynamicArray)
{
	set here = $namespace
	try {
		znspace ns
		set statement = ##class(%SQL.Statement).%New()
		set sc = statement.%Prepare("select top ? ID, ConfigName, Job, MessageId, SessionId, SourceClass, SourceMethod, Text, TimeLogged, TraceCat, Type from Ens_Util.Log order by ID desc")
		if $$$ISERR(sc) {
			do page.unread.%Push(ns _ " (" _ $system.Status.GetErrorText(sc) _ ")")
			znspace here
			quit
		}
		set rs = statement.%Execute(limit)
		if rs.%SQLCODE < 0 {
			do page.unread.%Push(ns _ " (" _ rs.%Message _ ")")
			znspace here
			quit
		}
		while rs.%Next() {
			set raw = {}
			for field = "ID", "ConfigName", "Job", "MessageId", "SessionId", "SourceClass", "SourceMethod", "Text", "TimeLogged", "TraceCat", "Type" {
				do raw.%Set(field, rs.%Get(field))
			}
			do page.events.%Push(##class(FlightDeck.Logs.Event).New(
				..#SOURCE, ns _ ":" _ rs.%Get("ID"), rs.%Get("TimeLogged"), ..Severity(rs.%Get("Type")),
				..Message(rs), raw,
				{"namespace":(ns), "process":(rs.%Get("Job"))}))
		}
		do read.%Push(ns)
		znspace here
	} catch e {
		do page.unread.%Push(ns _ " (" _ e.DisplayString() _ ")")
		if $namespace '= here znspace here
	}
}

/// Ens.DataType.LogType, mapped: 1 assert and 2 error are errors, 3 is a warning, 4 info and 5 trace
/// are informational. The platform stated the level; FlightDeck only renames it.
ClassMethod Severity(type As %String) As %String
{
	quit $case(+type, 1:"error", 2:"error", 3:"warning", 4:"info", 5:"info", :"unknown")
}

ClassMethod Message(rs As %SQL.StatementResult) As %String
{
	set text = rs.%Get("Text")
	set where = rs.%Get("ConfigName")
	set:where="" where = rs.%Get("SourceClass")
	quit $select(where'="":where _ ": ", 1:"") _ text
}

}

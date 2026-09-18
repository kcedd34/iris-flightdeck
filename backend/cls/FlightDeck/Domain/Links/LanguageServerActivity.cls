/// Link provider "language-server-activity": what an external language server is doing right now.
Class FlightDeck.Domain.Links.LanguageServerActivity [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/ext-lang-server/activity")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("language-server-activity", "current activity", "out")
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/ext-lang-server/activity", {"name":(entity.keys.name), "maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, "GET /v2/ext-lang-server/activity", status, $get(json), $get(raw))
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .row) {
		do group.items.%Push({"entityType":"ext-lang-server", "domain":"system", "displayName":($select(row.%IsDefined("Pid"):"pid "_row.Pid, 1:entity.keys.name)), "keys":{"name":(entity.keys.name)}, "detail":($select(row.%IsDefined("State"):row.State, 1:""))})
	}
	set group.count = group.items.%Size()
	quit group
}

}

/// Link provider "fs-access-paths": the paths a file-system access purpose covers.
Class FlightDeck.Domain.Links.FsAccessPaths [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/fs-access-purpose/paths")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("fs-access-paths", "paths", "out")
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/fs-access-purpose/paths", {"name":(entity.keys.name), "maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, "GET /v2/fs-access-purpose/paths", status, $get(json), $get(raw))
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .row) {
		do group.items.%Push({"entityType":"fs-access-purpose", "domain":"system", "displayName":(row.Path), "keys":{"name":(entity.keys.name)}, "detail":($select(row.%IsDefined("Description"):row.Description, 1:""))})
	}
	set group.count = group.items.%Size()
	quit group
}

}

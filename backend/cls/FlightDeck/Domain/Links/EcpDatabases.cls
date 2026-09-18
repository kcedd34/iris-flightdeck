/// Link provider "ecp-databases": the databases an ECP data server serves.
Class FlightDeck.Domain.Links.EcpDatabases [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/ecp/data-server/databases")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("ecp-databases", "databases served", "out")
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/ecp/data-server/databases", {"name":(entity.keys.name), "maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, "GET /v2/ecp/data-server/databases", status, $get(json), $get(raw))
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .row) {
		do group.items.%Push({"entityType":"database", "domain":"system", "displayName":(row.Name), "keys":{"name":(row.Name)}, "detail":(row.Directory)})
	}
	set group.count = group.items.%Size()
	quit group
}

}

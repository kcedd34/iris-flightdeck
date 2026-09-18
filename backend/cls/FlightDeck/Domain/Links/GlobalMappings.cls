/// Link provider "global-mappings": the global mappings of a namespace.
Class FlightDeck.Domain.Links.GlobalMappings [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/namespace/global-mappings")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("global-mappings", "global mappings", "out")
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/namespace/global-mappings", {"namespace":(entity.keys.name), "maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, "GET /v2/namespace/global-mappings", status, $get(json), $get(raw))
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .row) {
		do group.items.%Push({"entityType":"global-mapping", "domain":"system", "displayName":(row.Name), "keys":{"namespace":(entity.keys.name), "name":(row.Name)}, "detail":(row.Database)})
	}
	set group.count = group.items.%Size()
	quit group
}

}

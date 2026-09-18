/// Link provider "oauth2-resource-server-mappings": the service mappings of an OAuth 2.0 resource
/// server. The official listing answers per service, so the resource server's own name is what this
/// group asks with.
Class FlightDeck.Domain.Links.ResourceServerMappings [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/oauth2/resource-server/mappings")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("oauth2-resource-server-mappings", "service mappings", "out")
	set service = entity.keys.name
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/security/oauth2/resource-server/mappings", {"service":(service), "maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, "GET /v2/security/oauth2/resource-server/mappings", status, $get(json), $get(raw))
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .row) {
		set key = $select(row.%IsDefined("Key"):row.Key, row.%IsDefined("Name"):row.Name, 1:"")
		do group.items.%Push({
			"entityType":"oauth2-resource-server-mapping", "domain":"security",
			"displayName":(key), "keys":{"service":(service), "key":(key)},
			"detail":($select(row.%IsDefined("Value"):row.Value, 1:""))
		})
	}
	set group.count = group.items.%Size()
	quit group
}

}

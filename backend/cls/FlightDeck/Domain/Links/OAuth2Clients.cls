/// Link provider "oauth2-clients": the client configurations registered against a server definition.
/// <p>The official listing answers per server, which is exactly the entity being inspected, so no
/// parameter is needed: the server's own id is the parameter.
Class FlightDeck.Domain.Links.OAuth2Clients [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/oauth2/client/client-configurations")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("oauth2-clients", "client configurations use this server", "in")
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/security/oauth2/client/client-configurations", {"serverId":(entity.keys.serverId), "maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, "GET /v2/security/oauth2/client/client-configurations", status, $get(json), $get(raw))
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .client) {
		do group.items.%Push({"entityType":"oauth2-client", "domain":"security", "displayName":(client.ApplicationName), "keys":{"applicationName":(client.ApplicationName)}, "detail":(client.ClientType)})
	}
	set group.count = group.items.%Size()
	quit group
}

}

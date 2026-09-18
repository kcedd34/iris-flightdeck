/// Link provider "wallet-secrets": the secrets a collection holds, by name and type.
/// <p>The official API has no operation that reads a secret's value, and FlightDeck asks for none:
/// this group is the complete truth the platform offers about them (Constitution VI, spec FR-015).
Class FlightDeck.Domain.Links.WalletSecrets [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/wallet/secrets")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("wallet-secrets", "secrets in this collection", "out")
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/wallet/secrets", {"collection":(entity.keys.name), "maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, "GET /v2/wallet/secrets", status, $get(json), $get(raw))
	set iter = $select($isobject(json) && $isobject(json.result):json.result, 1:[]).%GetIterator()
	while iter.%GetNext(, .secret) {
		do group.items.%Push({"entityType":"wallet-secret", "domain":"security", "displayName":(secret.Name), "keys":{"name":(secret.Name)}, "detail":(secret.Type)})
	}
	set group.count = group.items.%Size()
	quit group
}

}

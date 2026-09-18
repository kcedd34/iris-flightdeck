/// Impact of changing or deleting a wallet collection (feature 003 spec FR-017): how many secrets it
/// holds and who can use them today.
Class FlightDeck.Domain.Impact.WalletImpact [ Abstract ]
{

ClassMethod Impact(current As %DynamicObject, ctx As %DynamicObject) As %DynamicObject
{
	set name = ctx.keys.name
	set entity = {"entityType":"wallet-collection", "keys":{"name":(name)}, "object":(ctx.current), "facts":{}}
	set secrets = ##class(FlightDeck.Domain.Links.WalletSecrets).Group(entity)
	if secrets.state '= "ok" {
		quit {"state":"undetermined", "summary":("The secrets in " _ name _ " could not be read."), "reason":(secrets.reason)}
	}
	set users = ##class(FlightDeck.Domain.Links.WalletUsers).Group(entity)
	set names = []
	if users.state '= "ok" {
		// What is known is said; what could not be read is named. An answer that listed only the
		// secrets would read as "nobody is affected", which is not what the portal knows (FR-009).
		quit {
			"state": "undetermined",
			"summary": (secrets.items.%Size() _ " " _ $select(secrets.items.%Size()=1:"secret is", 1:"secrets are") _ " in this collection. Who can use them could not be determined."),
			"reason": (users.reason),
			"objects": (secrets.items)
		}
	}
	set iter = users.items.%GetIterator()
	while iter.%GetNext(, .item) { do names.%Push(item.displayName) }
	if (secrets.items.%Size() = 0) && (names.%Size() = 0) quit {"state":"none", "summary":("The collection " _ name _ " holds no secret.")}
	set summary = secrets.items.%Size() _ " " _ $select(secrets.items.%Size()=1:"secret is", 1:"secrets are") _ " in this collection"
		_ $select(names.%Size()>0:", and " _ names.%Size() _ " " _ $select(names.%Size()=1:"user can use", 1:"users can use") _ " them", 1:"") _ "."
	quit {"state":"ok", "summary":(summary), "users":(names), "objects":(secrets.items)}
}

}

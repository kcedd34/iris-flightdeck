/// GET /v1/attention: what needs attention on the home panel (RN-FD-15, feature 003 spec FR-023).
/// <p>Today that is credentials whose certificate is expiring or already expired. The answer carries
/// only what this session may read: when a source is refused or a read cap is reached, the response
/// is marked degraded with the reason, and the panel says so instead of implying that nothing is
/// wrong (Constitution VIII).
Class FlightDeck.API.Attention [ Abstract ]
{

ClassMethod Get() As %Status
{
	set items = [], degraded = 0, reason = ""
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/security/x509-credentials", {"maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status = 200 {
		set credentials = $select($isobject(json) && $isobject(json.result):json.result, 1:[])
		set iter = credentials.%GetIterator()
		while iter.%GetNext(, .credential) {
			set facts = ##class(FlightDeck.Security.Validity).For(credential.Alias)
			if facts.band = "not-read" {
				set degraded = 1, reason = facts.reason
				continue
			}
			continue:'##class(FlightDeck.Security.Validity).NeedsAttention(facts.band)
			set item = {
				"kind": ($select(facts.band="expired":"expired-credential", 1:"expiring-credential")),
				"label": (..Label(credential.Alias, facts)),
				"band": (facts.band),
				"target": {"domain":"security", "entityType":"x509-credential", "keys":{"alias":(credential.Alias)}}
			}
			do item.%Set("daysRemaining", facts.daysRemaining, "number")
			do items.%Push(item)
		}
	} elseif status = 403 {
		set degraded = 1
		set op = ##class(FlightDeck.Capability.Map).Operation("GET /v2/security/x509-credentials")
		set reason = $select($isobject(op):##class(FlightDeck.API.Response).RequiresMessage(op.requires), 1:##class(FlightDeck.Admin.Client).ErrorText(json, raw))
	} elseif status = 501 {
		set degraded = 1
		set reason = ##class(FlightDeck.Admin.Client).UnavailableReason("GET /v2/security/x509-credentials")
	} else {
		set degraded = 1
		set reason = ##class(FlightDeck.Admin.Client).ErrorText($get(json), $get(raw))
	}
	set response = {"items":(items)}
	do response.%Set("degraded", degraded, "boolean")
	do response.%Set("reason", reason, $select(reason="":"null", 1:"string"))
	quit ##class(FlightDeck.API.Response).WriteJSON(response)
}

/// "fd_demo expires in 12 days" / "fd_demo expired 3 days ago".
ClassMethod Label(alias As %String, facts As %DynamicObject) As %String
{
	set days = +facts.daysRemaining
	if facts.band = "expired" quit alias _ " expired " _ $select(days = -1:"yesterday", 1:(-days) _ " days ago")
	quit alias _ " expires " _ $select(days = 0:"today", days = 1:"tomorrow", 1:"in " _ days _ " days")
}

}

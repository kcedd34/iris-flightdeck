/// Certificate validity for items that have one (feature 003 spec FR-022, FR-022a; probe P3).
/// <p>The official credentials listing carries no validity: it comes from
/// GET /v2/security/x509-credential/certificate, one alias at a time. A list of N credentials would
/// therefore cost N extra reads, so this class caches them for the request and stops at a declared
/// cap. Beyond the cap, or when a read is refused, the item reports "not read" with the reason and
/// is never counted as valid (Constitution VIII: a screen says what it does not know).
Class FlightDeck.Security.Validity [ Abstract ]
{

/// Items inside this many days are in the alert window.
Parameter ALERTDAYS = 30;

/// Certificate reads allowed for one request. Beyond it, items report "not read".
Parameter MAXREADS = 25;

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/x509-credential/certificate")
}

/// The certificate of one credential, cached per request. Returns "" when it could not be read.
ClassMethod Certificate(alias As %String, Output reason As %String) As %DynamicObject
{
	set reason = ""
	if $data(%FlightDeckCertificate(alias)) {
		set cached = %FlightDeckCertificate(alias)
		set reason = $list(cached, 2)
		quit $select($list(cached, 1)="":"", 1:##class(%DynamicAbstractObject).%FromJSON($list(cached, 1)))
	}
	set %FlightDeckCertificateReads = $get(%FlightDeckCertificateReads) + 1
	if %FlightDeckCertificateReads > ..#MAXREADS {
		set reason = "Validity not read: this view already read "_..#MAXREADS_" certificates, the limit for one request."
		set %FlightDeckCertificate(alias) = $listbuild("", reason)
		quit ""
	}
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/security/x509-credential/certificate", {"alias":(alias)}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500, raw = $system.Status.GetErrorText(sc)
	if status '= 200 {
		set reason = "Validity not read: " _ ##class(FlightDeck.Admin.Client).ErrorText($get(json), $get(raw))
		set %FlightDeckCertificate(alias) = $listbuild("", reason)
		quit ""
	}
	set certificate = json.result
	set %FlightDeckCertificate(alias) = $listbuild(certificate.%ToJSON(), "")
	quit certificate
}

/// Validity facts for a credential: {band, daysRemaining, notAfter, reason}.
/// Bands: valid, expiring (inside the alert window), expired, unknown (the platform reports none),
/// not-read (a cap or a refusal stopped the read).
ClassMethod For(alias As %String) As %DynamicObject
{
	set certificate = ..Certificate(alias, .reason)
	if '$isobject(certificate) {
		set facts = {"band":"not-read", "notAfter":""}
		do facts.%Set("daysRemaining", "", "null")
		do facts.%Set("reason", reason, $select(reason="":"null", 1:"string"))
		quit facts
	}
	quit ..FromNotAfter(certificate.ValidityNotAfter)
}

/// The same facts from a validity date, so callers that already read it do not read it again.
/// The official format is "YYYY-MM-DD HH:MM:SS"; anything else is reported as unknown.
ClassMethod FromNotAfter(notAfter As %String) As %DynamicObject
{
	set facts = {"notAfter":(notAfter)}
	do facts.%Set("reason", "", "null")
	set date = $piece(notAfter, " ", 1)
	if (notAfter = "") || (date '? 4N1"-"2N1"-"2N) {
		set facts.band = "unknown"
		do facts.%Set("daysRemaining", "", "null")
		set facts.reason = "The platform reports no validity for this item."
		quit facts
	}
	set days = $zdateh(date, 3) - +$horolog
	do facts.%Set("daysRemaining", days, "number")
	set facts.band = $select(days < 0:"expired", days <= ..#ALERTDAYS:"expiring", 1:"valid")
	quit facts
}

/// True when a band belongs on the home panel's attention list.
ClassMethod NeedsAttention(band As %String) As %Boolean
{
	quit $listfind($listbuild("expiring", "expired"), band) > 0
}

}

/// Link provider "certificate": what the platform reports about the certificate behind an X.509
/// credential — validity, issuer, subject and serial number (feature 003 probe P3).
/// <p>Read per alias and cached with a cap by FlightDeck.Security.Validity: the credentials listing
/// carries none of this.
Class FlightDeck.Domain.Links.Certificate [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/x509-credential/certificate")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("certificate", "certificate", "out")
	set certificate = ##class(FlightDeck.Security.Validity).Certificate(entity.keys.alias, .reason)
	if '$isobject(certificate) {
		set group.state = "undetermined"
		set group.reason = reason
		quit group
	}
	set facts = ##class(FlightDeck.Security.Validity).FromNotAfter(certificate.ValidityNotAfter)
	for pair = $listbuild("Subject", certificate.SubjectDN), $listbuild("Issuer", certificate.IssuerDN),
	           $listbuild("Serial number", certificate.SerialNumber),
	           $listbuild("Valid from", certificate.ValidityNotBefore), $listbuild("Valid until", certificate.ValidityNotAfter) {
		do group.items.%Push({"entityType":"certificate-field", "domain":"security", "displayName":($list(pair, 2)), "keys":{}, "detail":($list(pair, 1))})
	}
	set group.count = group.items.%Size()
	if facts.band '= "unknown" {
		set group.reason = $select(facts.band="expired":"Expired " _ (-facts.daysRemaining) _ " days ago.", 1:facts.daysRemaining _ " days remaining.")
	}
	quit group
}

}

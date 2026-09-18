/// Operations FlightDeck declines to offer, with the reason and the native path that performs them
/// (feature 003 spec FR-020 and FR-020a, research R12).
/// <p>Policy and version are different reasons for the same observable state, so both reach every
/// consumer the same way: the capability map reports available = false with the reason, and the
/// action bar, the palette, the mutation service and the router refuse through the mechanism that
/// already exists. Nothing here is a privilege, and nothing here asks the instance's version.
/// <p>A policy entry is a decision recorded in the specification, not a gap: the coverage document
/// lists each one, exactly as the journal origin of feature 001 is listed.
Class FlightDeck.Capability.Policy [ Abstract ]
{

XData Declined [ MimeType = application/json ]
{
{
 "POST /v2/security/encryption/file": {
  "reason": "FlightDeck does not create encryption key files. A mistake here can make an instance's data permanently unreadable, and the portal cannot undo it.",
  "nativePath": "System Administration > Encryption in the platform's management portal"
 },
 "POST /v2/security/encryption/file/admin": {
  "reason": "FlightDeck does not administer encryption key files. Key file administration decides who can activate the keys that make data readable.",
  "nativePath": "System Administration > Encryption in the platform's management portal"
 },
 "DELETE /v2/security/encryption/file/admin": {
  "reason": "FlightDeck does not administer encryption key files. Removing the last administrator of a key file can make its keys unusable.",
  "nativePath": "System Administration > Encryption in the platform's management portal"
 },
 "POST /v2/security/encryption/file/key": {
  "reason": "FlightDeck does not add keys to an encryption key file.",
  "nativePath": "System Administration > Encryption in the platform's management portal"
 },
 "DELETE /v2/security/encryption/file/key": {
  "reason": "FlightDeck does not delete keys from an encryption key file. A deleted key cannot decrypt what it encrypted.",
  "nativePath": "System Administration > Encryption in the platform's management portal"
 },
 "POST /v2/security/encryption/file/activate": {
  "reason": "FlightDeck does not activate or deactivate encryption keys. Activation decides which key the instance uses to read and write encrypted data.",
  "nativePath": "System Administration > Encryption in the platform's management portal"
 },
 "POST /v2/security/encryption/key/deactivate": {
  "reason": "FlightDeck does not activate or deactivate encryption keys.",
  "nativePath": "System Administration > Encryption in the platform's management portal"
 },
 "PUT /v2/security/encryption/settings": {
  "reason": "FlightDeck does not change encryption settings. They decide what the instance encrypts at startup, and a wrong value is discovered at the next restart.",
  "nativePath": "System Administration > Encryption in the platform's management portal"
 }
}
}

/// The declared table, cached per process.
ClassMethod Declined() As %DynamicObject
{
	quit ##class(FlightDeck.Domain.Descriptor).Load($classname(), "Declined")
}

/// The entry for an operationId, or "" when FlightDeck offers it.
ClassMethod Entry(operationId As %String) As %DynamicObject
{
	set found = ..Declined().%Get(operationId)
	quit $select($isobject(found):found, 1:"")
}

/// The reason, with the native path appended, or "" when the operation is offered.
ClassMethod Reason(operationId As %String) As %String
{
	set entry = ..Entry(operationId)
	quit:'$isobject(entry) ""
	quit entry.reason _ " Use " _ entry.nativePath _ "."
}

}

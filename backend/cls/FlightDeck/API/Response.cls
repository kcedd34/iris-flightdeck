/// JSON output and the FlightDeck error envelope
/// (contracts/flightdeck-api.openapi.json#/components/schemas/Error).
Class FlightDeck.API.Response [ Abstract ]
{

/// docs/prd.md section 9, message 1.
Parameter MSGINVALIDCREDENTIALS = "Invalid credentials. Check your username and password.";

/// docs/prd.md section 9, message 2 (placeholders [PERMISSION], [RESOURCE]).
Parameter MSGREQUIRES = "Requires [PERMISSION] on [RESOURCE]. Ask your instance administrator for access.";

/// docs/prd.md section 9, message 3.
Parameter MSGSAFEMODE = "Safe mode is on. Turn it off to make changes in this tab.";

/// docs/prd.md section 9, message 8.
Parameter MSGVERSION = "Not available on this IRIS version or edition. Requires IRIS 2026.2.";

/// Message 8 for an instance without any SysAdmin API FlightDeck speaks (FR-012a).
Parameter MSGNOAPI = "Not available on this IRIS version or edition. Requires IRIS 2026.1.";

/// docs/prd.md section 9, message 19.
Parameter MSGENTITYSEARCH = "Entity search is unavailable right now. Portal actions are still available.";

ClassMethod WriteJSON(obj As %DynamicAbstractObject, httpStatus As %Integer = 200) As %Status
{
	set %response.ContentType = "application/json"
	set %response.CharSet = "utf-8"
	set %response.Status = ..StatusLine(httpStatus)
	do %response.SetHeader("Cache-Control", "no-store")
	write obj.%ToJSON()
	quit $$$OK
}

/// Writes {"error":{code,message,raw,requires,detectedVersion}}.
ClassMethod WriteError(httpStatus As %Integer, code As %String, message As %String, raw As %String = "", requires As %DynamicArray = "", detectedVersion As %String = "") As %Status
{
	set err = {"code":(code), "message":(message)}
	do err.%Set("raw", $select(raw="":"", 1:raw), $select(raw="":"null", 1:"string"))
	if $isobject(requires) set err.requires = requires
	do err.%Set("detectedVersion", detectedVersion, $select(detectedVersion="":"null", 1:"string"))
	quit ..WriteJSON({"error":(err)}, httpStatus)
}

/// "Requires Use on %Admin_Secure. Ask …" or "Requires Use on %Admin_Manage or %Admin_Operate. Ask …"
ClassMethod RequiresMessage(requires As %DynamicArray) As %String
{
	set resources = ""
	for i=0:1:requires.%Size()-1 {
		set resources = resources _ $select(i=0:"", 1:" or ") _ $piece(requires.%Get(i), ":", 1)
	}
	quit $replace($replace(..#MSGREQUIRES, "[PERMISSION]", "Use"), "[RESOURCE]", resources)
}

ClassMethod StatusLine(code As %Integer) As %String
{
	quit code _ " " _ $case(code, 200:"OK", 201:"Created", 204:"No Content", 400:"Bad Request", 401:"Unauthorized", 403:"Forbidden", 404:"Not Found", 405:"Method Not Allowed", 409:"Conflict", 422:"Unprocessable Entity", 500:"Internal Server Error", 501:"Not Implemented", 502:"Bad Gateway", 504:"Gateway Timeout", :"Status")
}

}

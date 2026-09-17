/// Request object for in-process calls to the official API. %CSP.Request's ContentType setter is
/// private, and the official handlers reject a JSON body without it (HTTP 415).
Class FlightDeck.Admin.Request Extends %CSP.Request
{

Method SetContentType(contentType As %String)
{
	do ..ContentTypeSet(contentType)
}

}

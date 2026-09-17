/// GET /v1/palette/entities?q=&domain=&limit=
Class FlightDeck.API.Palette [ Abstract ]
{

ClassMethod Search() As %Status
{
	set q = $zstrip($get(%request.Data("q", 1)), "<>W")
	set domain = $get(%request.Data("domain", 1))
	set limit = $get(%request.Data("limit", 1), 5)
	if (q = "") || ($length(q) > 128) {
		quit ##class(FlightDeck.API.Response).WriteError(400, "BAD_REQUEST", "Query parameter q must be 1 to 128 characters.")
	}
	if (limit '? 1.2N) || (limit < 1) || (limit > 20) {
		quit ##class(FlightDeck.API.Response).WriteError(400, "BAD_REQUEST", "Query parameter limit must be between 1 and 20.")
	}
	if (domain '= "") && '$listfind($listbuild("web-apps", "permissions", "security", "tasks", "system", "logs"), domain) {
		quit ##class(FlightDeck.API.Response).WriteError(400, "BAD_REQUEST", "Unknown domain.")
	}
	quit ##class(FlightDeck.API.Response).WriteJSON(##class(FlightDeck.Palette.Search).Run(q, domain, +limit))
}

}

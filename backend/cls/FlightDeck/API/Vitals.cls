/// GET /v1/vitals
Class FlightDeck.API.Vitals [ Abstract ]
{

ClassMethod Get() As %Status
{
	quit ##class(FlightDeck.API.Response).WriteJSON({"vitals":(##class(FlightDeck.Vitals.Service).Snapshot())})
}

}

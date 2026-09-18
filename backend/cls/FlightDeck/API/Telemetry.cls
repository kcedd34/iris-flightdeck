/// GET /v1/telemetry and GET /v1/async/:handle (feature 004).
/// <p>Both are reads: they stay available while safe mode is armed, as every read does.
Class FlightDeck.API.Telemetry [ Abstract ]
{

ClassMethod Get() As %Status
{
	quit ##class(FlightDeck.API.Response).WriteJSON(##class(FlightDeck.Telemetry.Service).Reading())
}

/// The state, and when it has finished the value, of an asynchronous operation FlightDeck fired.
/// A handle that means nothing to the instance answers with the platform's own refusal, not with an
/// invented one.
ClassMethod Async(handle As %String) As %Status
{
	quit ##class(FlightDeck.API.Response).WriteJSON(##class(FlightDeck.Async.Runner).Read(handle))
}

}

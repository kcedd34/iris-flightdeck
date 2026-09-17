/// Test probe: a REST handler that fails the way %CSP.REST reports a <PROTECT> raised inside a
/// handler (an error %Status, HTTP 200 left in %response; spike T-EXEC-1 finding 5).
Class FlightDeck.Test.Probe.ProtectInHandler Extends %CSP.REST
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/protected" Method="GET" Call="Protected"/>
</Routes>
}

ClassMethod Protected() As %Status
{
	quit $$$ERROR($$$ObjectScriptError, "<PROTECT>Protected+1^FlightDeck.Test.Probe.ProtectInHandler.1 ^^/durable/iris/mgr/irissys/")
}

}

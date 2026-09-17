/// Test probe: declares static files but exposes a POST route, so it must NOT count as a verified
/// static-files dispatcher (feature 002 T022).
Class FlightDeck.Test.Probe.StaticWithPost Extends %CSP.REST
{

Parameter EXPOSURE = "static-files";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/(.*)" Method="GET" Call="Nothing"/>
<Route Url="/(.*)" Method="POST" Call="Nothing"/>
</Routes>
}

ClassMethod Nothing(path As %String) As %Status
{
	quit $$$OK
}

}

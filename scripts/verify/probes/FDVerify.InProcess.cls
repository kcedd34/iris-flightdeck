/// Day-1 probe 2, candidate in_process. Temporary: loaded, exercised and deleted by
/// scripts/verify/verify_platform.py. Never part of FlightDeck.
Class FDVerify.InProcess Extends %CSP.REST
{

Parameter UseSession = 1;

Parameter CONTENTTYPE = "application/json";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/whoami" Method="GET" Call="WhoAmI"/>
<Route Url="/admin/(.*)" Method="GET" Call="Admin"/>
</Routes>
}

ClassMethod WhoAmI() As %Status
{
	set %response.ContentType = "application/json"
	write {"user":($username), "roles":($roles), "namespace":($namespace)}.%ToJSON()
	quit $$$OK
}

/// Official SysAdmin API handler called in-process, in %SYS, under the authenticated user.
ClassMethod Admin(path As %String) As %Status
{
	new $namespace
	set $namespace = "%SYS"
	quit ##class(%Api.Admin).DispatchRequest("/"_path, "GET", 1)
}

}

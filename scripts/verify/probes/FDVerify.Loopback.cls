/// Day-1 probe 2, candidate loopback_proxy. Temporary: loaded, exercised and deleted by
/// scripts/verify/verify_platform.py. Forwards the caller's CSP session cookies to /api/admin
/// over HTTP loopback and returns the upstream answer verbatim.
Class FDVerify.Loopback Extends %CSP.REST
{

Parameter UseSession = 1;

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
	write {"user":($username)}.%ToJSON()
	quit $$$OK
}

ClassMethod Admin(path As %String) As %Status
{
	set req = ##class(%Net.HttpRequest).%New()
	set req.Server = "127.0.0.1"
	set req.Port = $get(^%SYS("WebServer","Port"), 52773)
	set req.Timeout = 20
	set cookies = ""
	set name = ""
	for {
		set name = $order(%request.Cookies(name))
		quit:name=""
		if name [ "CSPSESSIONID" {
			set cookies = cookies _ $select(cookies="":"", 1:"; ") _ name _ "=" _ %request.GetCookie(name)
		}
	}
	if cookies '= "" do req.SetHeader("Cookie", cookies)
	set sc = req.Get("/api/admin/" _ path)
	if $$$ISERR(sc) {
		set %response.Status = "502 Bad Gateway"
		write {"loopbackError":($system.Status.GetErrorText(sc))}.%ToJSON()
		quit $$$OK
	}
	set %response.Status = req.HttpResponse.StatusCode _ " " _ req.HttpResponse.ReasonPhrase
	set %response.ContentType = "application/json"
	if $isobject(req.HttpResponse.Data) { do req.HttpResponse.Data.OutputToDevice() } else { write req.HttpResponse.Data }
	quit $$$OK
}

}

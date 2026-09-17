/// Serves the FlightDeck single-page application from <mgr>/flightdeck/web (research R12).
/// Any path without a matching file returns index.html, so deep links like
/// /flightdeck/security/tls work on reload.
Class FlightDeck.UI.Static Extends %CSP.REST
{

Parameter UseSession = 0;

Parameter HandleCorsRequest = 0;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/(.*)" Method="GET" Call="Serve"/>
</Routes>
}

ClassMethod WebRoot() As %String
{
	quit ##class(%File).NormalizeDirectory("flightdeck/web", $system.Util.ManagerDirectory())
}

ClassMethod Serve(path As %String) As %Status
{
	set root = ..WebRoot()
	set path = $zstrip(path, "<", "/")
	if (path [ "..") || (path [ "\") || (path [ $char(0)) {
		set %response.Status = "404 Not Found"
		quit $$$OK
	}
	set file = ##class(%File).NormalizeFilename(path, root)
	if (path = "") || '##class(%File).Exists(file) || ##class(%File).DirectoryExists(file) {
		set path = "index.html"
		set file = ##class(%File).NormalizeFilename(path, root)
	}
	if '##class(%File).Exists(file) {
		set %response.Status = "404 Not Found"
		set %response.ContentType = "text/plain"
		write "FlightDeck web assets are not installed at ", root
		quit $$$OK
	}
	set ext = $zconvert($piece(path, ".", *), "L")
	set %response.ContentType = $case(ext, "html":"text/html", "js":"text/javascript", "css":"text/css", "json":"application/json", "svg":"image/svg+xml", "woff2":"font/woff2", "woff":"font/woff", "png":"image/png", "ico":"image/x-icon", :"application/octet-stream")
	if $case(ext, "html":1, "js":1, "css":1, "json":1, "svg":1, :0) set %response.CharSet = "utf-8"
	if $extract(path, 1, 7) = "assets/" {
		do %response.SetHeader("Cache-Control", "public, max-age=31536000, immutable")
	} else {
		do %response.SetHeader("Cache-Control", "no-cache")
	}
	set stream = ##class(%Stream.FileBinary).%New()
	set sc = stream.LinkToFile(file)
	quit:$$$ISERR(sc) sc
	quit stream.OutputToDevice()
}

}

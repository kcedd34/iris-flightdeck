/// Serves the FlightDeck single-page application from <mgr>/flightdeck/web (research R12).
/// Any path without a matching file returns index.html, so deep links like
/// /flightdeck/security/tls work on reload.
Class FlightDeck.UI.Static Extends %CSP.REST
{

/// Declares that this dispatcher serves only the built static files of the SPA. The web
/// applications list trusts it only together with a UrlMap that exposes GET routes alone
/// (FlightDeck.Domain.Facts.StaticFilesDispatcher; verification/flightdeck-web-apps-exposure-2026.2.md).
Parameter EXPOSURE = "static-files";

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
	// The files on disk are already encoded: the bundle is UTF-8 and the fonts are binary. Setting
	// %response.CharSet above makes CSP translate what it writes, so writing those bytes through it
	// encodes them a second time — every "—", "…", "×" and "→" in the interface arrived as mojibake,
	// and the served bundle was 183 bytes longer than the one on disk. Nothing caught it because
	// every Playwright project talks to the Vite dev server, so this class serves no test.
	set %response.NoCharSetConvert = 1
	if path = "index.html" quit ..ServeIndex(file)
	set stream = ##class(%Stream.FileBinary).%New()
	set sc = stream.LinkToFile(file)
	quit:$$$ISERR(sc) sc
	quit stream.OutputToDevice()
}

/// The public-demo notice, or "" (feature 007, the VM deployment).
/// <p>Read from the environment of the process serving the request, so it is a property of that
/// deployment and of nothing else. Absent by default: a local install never shows it, which is the
/// point. The published demo runs on a throwaway instance whose credentials are meant to be read by
/// anyone, so this is not secret material in the sense Constitution VI protects; it is a literal the
/// operator chose to publish, it never comes from the instance's security tables, and it does not
/// pass through the mutation layer or the session trail.
ClassMethod DemoNotice() As %String
{
	set user = $system.Util.GetEnviron("FD_DEMO_USER")
	set password = $system.Util.GetEnviron("FD_DEMO_PASSWORD")
	if (user = "") || (password = "") quit ""
	// The second account is optional: a deployment that declares only the first one still works, and
	// a local install still shows nothing at all. Tab-separated, in the order the form reads them.
	set reduced = $system.Util.GetEnviron("FD_DEMO_REDUCED_USER")
	set reducedPassword = $system.Util.GetEnviron("FD_DEMO_REDUCED_PASSWORD")
	if (reduced = "") || (reducedPassword = "") set reduced = "", reducedPassword = ""
	quit user _ $char(9) _ password _ $char(9) _ $system.Util.GetEnviron("FD_DEMO_RESET")
		_ $char(9) _ reduced _ $char(9) _ reducedPassword
}

/// index.html, with the demo notice injected as a meta tag when this deployment declares one.
/// <p>Injected at serve time rather than built in, so the committed bundle is identical on every
/// install and enabling the notice needs no rebuild.
ClassMethod ServeIndex(file As %String) As %Status
{
	// Read as bytes and spliced as bytes: the caller has turned character-set translation off, so
	// what is read here is written out unchanged, whatever the page and the injected value contain.
	set stream = ##class(%Stream.FileBinary).%New()
	set sc = stream.LinkToFile(file)
	quit:$$$ISERR(sc) sc
	set html = ""
	while 'stream.AtEnd { set html = html _ stream.Read(32000) }
	do stream.%Close()
	set notice = ..DemoNotice()
	if notice '= "" {
		set tag = "<meta name=""fd-demo-notice"" content=""" _ ..Attribute(notice) _ """ />"
		set html = $piece(html, "</head>", 1) _ tag _ "</head>" _ $piece(html, "</head>", 2, *)
	}
	write html
	quit $$$OK
}

/// Escapes a value for an HTML attribute.
ClassMethod Attribute(value As %String) As %String
{
	set value = $replace(value, "&", "&amp;")
	set value = $replace(value, """", "&quot;")
	set value = $replace(value, "<", "&lt;")
	quit $replace(value, ">", "&gt;")
}

}

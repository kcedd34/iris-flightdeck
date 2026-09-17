/// Server-computed facts that entity-type markers and mutation rules read (feature 002 research
/// R7, R10). Facts come from official API fields, the platform's REST discovery (%REST.API, the
/// documented UC04 gap) and the class dictionary; never from an object's name, except that
/// FlightDeck's own applications are identified by the installer's record.
Class FlightDeck.Domain.Facts [ Abstract ]
{

/// Seconds the REST dispatcher set is reused within one process.
Parameter RESTCACHE = 10;

/// Facts for a descriptor's facts kind. listItem is the official list object.
ClassMethod For(kind As %String, listItem As %DynamicObject) As %DynamicObject
{
	if kind = "web-application" quit ..WebApplication(listItem)
	quit {}
}

ClassMethod WebApplication(item As %DynamicObject) As %DynamicObject
{
	set methods = item.AuthenticationMethods
	set unauthenticated = ##class(FlightDeck.Domain.Predicate).ArrayHas(methods, "Unauthenticated")
	set only = unauthenticated && $isobject(methods) && (methods.%Size() = 1)
	set dispatch = item.DispatchClass
	set rest = 0, staticFiles = 0
	if dispatch '= "" {
		do ..RestApplications(item.Namespace, .complete, .known)
		// Unknown discovery (refused or failed) counts a dispatcher as REST: the stronger marker.
		set rest = $select('complete:1, 1:$data(known(item.Name)) > 0)
		set staticFiles = ..StaticFilesDispatcher(dispatch, item.Namespace)
	}
	set facts = {}
	do facts.%Set("unauthenticated", unauthenticated, "boolean")
	do facts.%Set("unauthenticatedOnly", only, "boolean")
	do facts.%Set("restDispatcher", rest, "boolean")
	do facts.%Set("staticFiles", staticFiles, "boolean")
	do facts.%Set("system", ..IsSystemApplication(item), "boolean")
	do facts.%Set("flightDeck", ..IsFlightDeckApplication(item.Name), "boolean")
	quit facts
}

/// Research R2: the API marks system applications through IsSystemApp or a Type containing
/// "System" (IsSystemApp is never set on IRIS 2026.2; verification/README.md).
ClassMethod IsSystemApplication(item As %DynamicObject) As %Boolean
{
	quit ''item.IsSystemApp || ($zconvert(item.Type, "U") [ "SYSTEM")
}

/// FlightDeck's own applications, as recorded by FlightDeck.Install.Installer.VerifyWebApps.
ClassMethod IsFlightDeckApplication(name As %String) As %Boolean
{
	quit:name="" 0
	quit $data(^FlightDeck.Install("applications", name)) > 0
}

/// The installer's record for one FlightDeck application, or "".
ClassMethod FlightDeckApplication(name As %String) As %DynamicObject
{
	quit:name="" ""
	set json = $get(^FlightDeck.Install("applications", name))
	quit $select(json="":"", 1:##class(%DynamicAbstractObject).%FromJSON(json))
}

/// Web applications whose dispatch class the platform reports as REST, by name, from
/// %REST.API.GetWebRESTApps(namespace) under the caller's identity. The platform answers per
/// namespace (the namespace's applications plus %SYS's). complete is 0 when discovery was refused.
ClassMethod RestApplications(namespace As %String, Output complete As %Boolean, Output names)
{
	kill names
	set key = $zconvert(namespace, "U")
	set cached = $get(%FlightDeckRestApps(key))
	if (cached '= "") && (($zhorolog - $list(cached, 1)) < ..#RESTCACHE) && ($list(cached, 2) = $username) {
		set complete = $list(cached, 3)
		merge names = %FlightDeckRestApps(key, "names")
		quit
	}
	set complete = 0
	try {
		new $namespace
		set $namespace = "%SYS"
		set sc = ##class(%REST.API).GetWebRESTApps(namespace, .list)
		if $$$ISOK(sc), $isobject($get(list)) {
			for i=1:1:list.Count() { set names(list.GetAt(i).name) = "" }
			set complete = 1
		}
	} catch {
		set complete = 0
	}
	kill %FlightDeckRestApps(key)
	set %FlightDeckRestApps(key) = $listbuild($zhorolog, $username, complete)
	merge %FlightDeckRestApps(key, "names") = names
}

/// A dispatch class serves only static files when it declares Parameter EXPOSURE = "static-files"
/// AND its compiled UrlMap exposes only GET or HEAD routes. Reads the class dictionary only; no
/// code of the class runs. Unreadable namespaces answer 0.
ClassMethod StaticFilesDispatcher(class As %String, namespace As %String) As %Boolean
{
	set result = 0
	try {
		new $namespace
		if namespace '= "" set $namespace = namespace
		set parameter = ##class(%Dictionary.CompiledParameter).%OpenId(class _ "||EXPOSURE")
		if '$isobject(parameter) || (parameter.Default '= "static-files") quit
		set xdata = ##class(%Dictionary.CompiledXData).%OpenId(class _ "||UrlMap")
		if '$isobject(xdata) quit
		set onlyReads = 1, routes = 0
		while 'xdata.Data.AtEnd {
			set line = xdata.Data.ReadLine()
			// A <Map> forwards to another dispatcher, whose routes are not checked here.
			if line [ "<Map " set onlyReads = 0
			continue:line'["<Route "
			set routes = routes + 1
			set method = $zconvert($piece($piece(line, "Method=""", 2), """", 1), "U")
			if '$listfind($listbuild("GET", "HEAD"), method) set onlyReads = 0
		}
		set result = onlyReads && (routes > 0)
	} catch {
		set result = 0
	}
	quit result
}

}

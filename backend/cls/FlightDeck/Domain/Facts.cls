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
	if kind = "user" quit ..User(listItem)
	if kind = "x509-credential" quit ..Credential(listItem)
	if kind = "wallet-collection" quit ..WalletCollection(listItem)
	quit {}
}

/// Bits of the official AutheEnabled field that mean the account is authenticated elsewhere:
/// delegated (Zen/OS delegated) and LDAP. Roles may then be assigned at login by that mechanism,
/// which the portal does not manage (feature 003 spec FR-004).
Parameter AUTHEDELEGATED = 8;

Parameter AUTHELDAP = 1024;

/// Facts for a user: enabled, expired (the date, never the flag alone), external authentication.
/// <p>The official user listing carries no ExpirationDate, so expiry is known on the detail and
/// unknown on the list. `expiryKnown` says which, and no marker claims an account is current when
/// the source could not say (probe P1, Constitution VIII).
ClassMethod User(item As %DynamicObject) As %DynamicObject
{
	set facts = {}
	do facts.%Set("enabled", ''item.Enabled, "boolean")
	do facts.%Set("expiryKnown", item.%IsDefined("ExpirationDate"), "boolean")
	do facts.%Set("expired", item.%IsDefined("ExpirationDate") && ..Expired(item.ExpirationDate), "boolean")
	set bits = +item.AutheEnabled
	set external = ($zboolean(bits, ..#AUTHEDELEGATED, 1) = ..#AUTHEDELEGATED) || ($zboolean(bits, ..#AUTHELDAP, 1) = ..#AUTHELDAP)
	do facts.%Set("externalAuthentication", external, "boolean")
	quit facts
}

/// The official "no limit" values for an account's expiry date. IRIS 2026.2 normalises the sentinel
/// to an empty string; IRIS 2026.1 returns it literally, as the schema's own description allows
/// ("If there is no limit, this value may be 1840-12-31 or ..."). Reading the sentinel as a date in
/// the past would make every account look expired, which is how it was found.
Parameter NOEXPIRY = "1840-12-31";

/// True when the account's expiry date is in the past. An expired account is still reported as
/// enabled, so the date decides; a sentinel is not a date.
ClassMethod Expired(expirationDate As %String) As %Boolean
{
	quit:$get(expirationDate)="" 0
	set date = $piece(expirationDate, " ", 1)
	quit:date=..#NOEXPIRY 0
	quit:'(date?4N1"-"2N1"-"2N) 0
	set days = $zdateh(date, 3, , , , , , , "")
	quit:days="" 0
	quit:(days<=$zdateh(..#NOEXPIRY, 3)) 0
	quit days < +$horolog
}

/// Facts for a wallet collection: how many secrets it holds, which the reinforced delete states.
/// The listing returns names and types only; no value is ever read (Constitution VI).
ClassMethod WalletCollection(item As %DynamicObject) As %DynamicObject
{
	set facts = {}
	set sc = ##class(FlightDeck.Domain.Upstream).Call("GET", "/v2/wallet/secrets", {"collection":(item.Name), "maxRows":1000}, "", .status, .json, .raw)
	if $$$ISERR(sc) set status = 500
	if status '= 200 {
		do facts.%Set("secretCountKnown", 0, "boolean")
		quit facts
	}
	do facts.%Set("secretCountKnown", 1, "boolean")
	do facts.%Set("secretCount", $select($isobject(json) && $isobject(json.result):json.result.%Size(), 1:0), "number")
	quit facts
}

/// Facts for an X.509 credential: the validity band and days remaining (feature 003 FR-022).
ClassMethod Credential(item As %DynamicObject) As %DynamicObject
{
	set validity = ##class(FlightDeck.Security.Validity).For(item.Alias)
	set facts = {"validityBand":(validity.band)}
	do facts.%Set("daysRemaining", validity.daysRemaining, $select(validity.daysRemaining="":"null", 1:"number"))
	do facts.%Set("validityReason", validity.reason, $select(validity.reason="":"null", 1:"string"))
	do facts.%Set("hasPrivateKey", ''item.HasPrivateKey, "boolean")
	quit facts
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

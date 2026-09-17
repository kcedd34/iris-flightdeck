/// REST service discovery for the explorer (UC04, feature 002 research R9). Uses %REST.API, the
/// documented public class behind /api/mgmnt (the UC04 gap named in Constitution I), in-process
/// under the signed-in user's identity. Refusals are reported verbatim; no privilege is invented.
/// <p>hasSpecification is true for specification-first services and for dispatch classes that
/// publish their own document (ClassMethod PublishedSpecification). A document the platform
/// generates from a hand-coded UrlMap does not count: it is exposed as routes (metadata).
Class FlightDeck.Rest.Discovery [ Abstract ]
{

/// {services: [...], namespaces: [...]}
ClassMethod Services() As %DynamicObject
{
	set services = [], namespaces = [], errors = ""
	kill specByDispatch, specNames
	// Specification-first applications.
	try {
		new $namespace
		set $namespace = "%SYS"
		set sc = ##class(%REST.API).GetAllRESTApps(.specs)
		if $$$ISERR(sc) {
			set errors = $system.Status.GetErrorText(sc)
		} else {
			for i=1:1:specs.Count() {
				set app = specs.GetAt(i)
				set specByDispatch(app.dispatchClass) = $listbuild(app.name, app.namespace, app.webApplications)
			}
		}
	} catch ex {
		set errors = ex.DisplayString()
	}
	// Web applications whose dispatch class is REST, in every namespace.
	try {
		new $namespace
		set $namespace = "%SYS"
		set sc = ##class(%REST.API).GetAllWebRESTApps(.web)
		if $$$ISERR(sc) quit
		for i=1:1:web.Count() {
			set app = web.GetAt(i)
			set spec = $get(specByDispatch(app.dispatchClass))
			set published = ..PublishesSpecification(app.dispatchClass, app.namespace)
			set service = {"name":(app.name), "webApplication":(app.name), "namespace":(app.namespace), "dispatchClass":(app.dispatchClass)}
			do service.%Set("enabled", ''app.enabled, "boolean")
			do service.%Set("kind", $select(spec'="":"specification-first", 1:"hand-coded"))
			do service.%Set("hasSpecification", (spec '= "") || published, "boolean")
			if spec '= "" {
				set service.specificationSource = "specification-first", service.specificationName = $list(spec, 1)
				set specNames($list(spec, 1)) = ""
			} elseif published {
				set service.specificationSource = "published"
			} else {
				do service.%Set("specificationSource", "", "null")
			}
			do service.%Set("routesReportedByPlatform", (spec = "") && 'published, "boolean")
			set service.markers = ..Markers(service)
			do services.%Push(service)
			set seenNamespace(app.namespace) = ""
		}
	} catch ex {
		set errors = errors _ $select(errors="":"", 1:" ") _ ex.DisplayString()
	}
	// Specification-first applications no web application serves directly.
	set dispatch = ""
	for {
		set dispatch = $order(specByDispatch(dispatch), 1, spec)
		quit:dispatch=""
		continue:$data(specNames($list(spec, 1)))
		set service = {"name":($list(spec, 1)), "webApplication":"", "namespace":($list(spec, 2)), "dispatchClass":(dispatch), "kind":"specification-first", "specificationSource":"specification-first", "specificationName":($list(spec, 1))}
		do service.%Set("enabled", 0, "boolean")
		do service.%Set("hasSpecification", 1, "boolean")
		do service.%Set("routesReportedByPlatform", 0, "boolean")
		set service.markers = ..Markers(service)
		do services.%Push(service)
		set seenNamespace($list(spec, 2)) = ""
	}
	set ns = ""
	for { set ns = $order(seenNamespace(ns)) quit:ns=""  do namespaces.%Push({"name":(ns), "state":"ok", "reason":null}) }
	if errors '= "" do namespaces.%Push({"name":"", "state":"forbidden", "reason":(errors)})
	quit {"services":(services), "namespaces":(namespaces)}
}

ClassMethod Markers(service As %DynamicObject) As %DynamicArray
{
	set markers = []
	if 'service.hasSpecification do markers.%Push({"id":"no-specification", "text":"No specification", "tone":"caution"})
	if service.specificationSource = "published" do markers.%Push({"id":"published", "text":"Published specification", "tone":"neutral"})
	if service.webApplication = "" {
		do markers.%Push({"id":"no-web-application", "text":"No web application serves it directly", "tone":"neutral"})
	} elseif 'service.enabled {
		do markers.%Push({"id":"disabled", "text":"Disabled", "tone":"neutral"})
	}
	quit markers
}

/// True when the dispatch class implements ClassMethod PublishedSpecification (dictionary read only).
ClassMethod PublishesSpecification(class As %String, namespace As %String) As %Boolean
{
	set result = 0
	try {
		new $namespace
		set $namespace = namespace
		set method = ##class(%Dictionary.CompiledMethod).%OpenId(class _ "||PublishedSpecification")
		set result = $isobject(method) && method.ClassMethod
	} catch {
		set result = 0
	}
	quit result
}

/// The service with this web application (or specification name), from a fresh discovery.
ClassMethod Find(webApplication As %String, name As %String = "") As %DynamicObject
{
	set iter = ..Services().services.%GetIterator()
	while iter.%GetNext(, .service) {
		if (webApplication '= "") && (service.webApplication = webApplication) return service
		if (webApplication = "") && (service.name = name) return service
	}
	quit ""
}

/// SpecificationResponse for a service: {format, document} or {format:"routes", routes}.
ClassMethod Specification(service As %DynamicObject, Output status As %Integer, Output error As %String) As %DynamicObject
{
	set status = 200, error = ""
	set response = {}
	try {
		if service.specificationSource = "published" {
			new $namespace
			set $namespace = service.namespace
			set document = $classmethod(service.dispatchClass, "PublishedSpecification")
			set response.format = $select(document.openapi'="":"openapi-3.0", 1:"openapi-2.0")
			set response.document = document
			do response.%Set("routes", "", "null")
		} elseif service.specificationSource = "specification-first" {
			new $namespace
			set $namespace = "%SYS"
			set sc = ##class(%REST.API).GetApplication(service.specificationName, .document)
			if $$$ISERR(sc) set status = 403, error = $system.Status.GetErrorText(sc) quit
			set response.format = $select(document.openapi'="":"openapi-3.0", 1:"openapi-2.0")
			set response.document = document
			do response.%Set("routes", "", "null")
		} else {
			new $namespace
			set $namespace = "%SYS"
			set sc = ##class(%REST.API).GetWebRESTApplication(service.namespace, service.webApplication, .generated)
			if $$$ISERR(sc) set status = 403, error = $system.Status.GetErrorText(sc) quit
			set routes = []
			set paths = generated.paths.%GetIterator()
			while paths.%GetNext(.path, .item) {
				set methods = item.%GetIterator()
				while methods.%GetNext(.method, .op) {
					continue:'$isobject(op)
					do routes.%Push({"method":($zconvert(method, "U")), "path":(path), "call":(op.%Get("x-ISC_ServiceMethod"))})
				}
			}
			set response.format = "routes"
			do response.%Set("document", "", "null")
			set response.routes = routes
		}
	} catch ex {
		set status = $select(ex.Name="<PROTECT>":403, 1:500), error = ex.DisplayString()
	}
	quit response
}

}

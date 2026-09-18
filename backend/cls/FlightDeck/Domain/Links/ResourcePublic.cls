/// Link provider "resource-public": the resource's public permission, which every user holds
/// (GET /v2/security/resource; feature 002 research R6).
Class FlightDeck.Domain.Links.ResourcePublic [ Abstract ]
{

ClassMethod Operations() As %List
{
	quit $listbuild("GET /v2/security/resource")
}

ClassMethod Group(entity As %DynamicObject, params As %DynamicObject = "") As %DynamicObject
{
	set resource = entity.object.Resource
	quit:resource="" ""
	set group = ##class(FlightDeck.Domain.LinkProviders).NewGroup("resource-public", "public permission")
	set detail = ##class(FlightDeck.Admin.Client).Get("/v2/security/resource", {"name":(resource)}, .status, .raw)
	if status '= 200 quit ##class(FlightDeck.Domain.LinkProviders).FromFailure(group, "GET /v2/security/resource", status, "", raw)
	set permission = detail.PublicPermission
	set group.label = $select(permission="":"No public permission on "_resource, 1:"Every user holds "_permission_" on "_resource_" publicly")
	set group.count = $select(permission="":0, 1:1)
	quit group
}

/// The public permission of a resource, "" when none; failure set when the read failed.
ClassMethod Permission(resource As %String, Output failure As %DynamicObject) As %String
{
	set failure = ""
	set detail = ##class(FlightDeck.Admin.Client).Get("/v2/security/resource", {"name":(resource)}, .status, .raw)
	if status '= 200 set failure = {"operationId":"GET /v2/security/resource", "status":(status), "json":"", "raw":(raw)} quit ""
	quit detail.PublicPermission
}

}

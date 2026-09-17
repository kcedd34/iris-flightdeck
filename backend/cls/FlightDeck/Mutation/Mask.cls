/// Secret masking for the mutation layer (Constitution VI, feature 002 spec FR-016). Applied by
/// FlightDeck.Mutation.Service to every preview row, apply result, trail record and error text
/// before anything leaves the server. The trail never decides what is secret.
Class FlightDeck.Mutation.Mask [ Abstract ]
{

Parameter REDACTED = "[secret]";

ClassMethod IsSecret(secretFields As %DynamicArray, field As %String) As %Boolean
{
	quit ##class(FlightDeck.Domain.Predicate).ArrayHas(secretFields, field)
}

/// Removes secret fields from an object (in place) and returns it.
ClassMethod Object(object As %DynamicObject, secretFields As %DynamicArray) As %DynamicObject
{
	quit:'$isobject(object) object
	quit:'$isobject(secretFields) object
	set iter = secretFields.%GetIterator()
	while iter.%GetNext(, .field) { do object.%Remove(field) }
	quit object
}

/// Replaces every secret value that appears in a text (for example an IRIS error that echoes input).
ClassMethod Text(text As %String, values As %DynamicObject, secretFields As %DynamicArray) As %String
{
	quit:'$isobject(values) text
	quit:'$isobject(secretFields) text
	set iter = secretFields.%GetIterator()
	while iter.%GetNext(, .field) {
		continue:'values.%IsDefined(field)
		set value = values.%Get(field)
		if ('$isobject(value)) && ($length(value) > 0) set text = $replace(text, value, ..#REDACTED)
	}
	quit text
}

/// Masks headers and body of a REST test request (request mode): Authorization-like headers and any
/// declared secret header are replaced (spec FR-039).
ClassMethod Request(request As %DynamicObject) As %DynamicObject
{
	quit:'$isobject(request) request
	set copy = ##class(%DynamicAbstractObject).%FromJSON(request.%ToJSON())
	if $isobject(copy.headers) {
		set iter = copy.headers.%GetIterator()
		while iter.%GetNext(.name) {
			if $listfind($listbuild("authorization", "cookie", "proxy-authorization", "x-api-key"), $zconvert(name, "L")) do copy.headers.%Set(name, ..#REDACTED)
		}
	}
	quit copy
}

}

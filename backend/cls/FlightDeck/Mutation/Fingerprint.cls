/// State fingerprint for optimistic concurrency (feature 002 research R4). The official API has no
/// version token, so the mutation layer compares a hash of the object it read for the preview with
/// a hash of the object re-read immediately before writing.
/// <p>Canonical JSON: object keys sorted, arrays in order. Secret fields enter only as their own
/// hash, so no secret value is carried by the fingerprint (Constitution VI).
Class FlightDeck.Mutation.Fingerprint [ Abstract ]
{

Parameter ABSENT = "absent";

ClassMethod Of(object As %DynamicAbstractObject, secretFields As %DynamicArray = "") As %String
{
	quit:'$isobject(object) ..#ABSENT
	set copy = ##class(%DynamicAbstractObject).%FromJSON(object.%ToJSON())
	if $isobject(secretFields) {
		set iter = secretFields.%GetIterator()
		while iter.%GetNext(, .field) {
			if copy.%IsDefined(field) do copy.%Set(field, ..Hex($system.Encryption.SHAHash(256, $zconvert("secret:"_copy.%Get(field), "O", "UTF8"))))
		}
	}
	quit ..Hex($system.Encryption.SHAHash(256, $zconvert(..Canonical(copy), "O", "UTF8")))
}

/// Deterministic JSON text: object keys in sorted order.
ClassMethod Canonical(node) As %String
{
	if '$isobject(node) quit ..Scalar(node)
	if node.%IsA("%DynamicArray") {
		set out = "[", iter = node.%GetIterator(), first = 1
		while iter.%GetNext(.i, .value) {
			set out = out _ $select(first:"", 1:",") _ ..Value(node, i, value), first = 0
		}
		quit out _ "]"
	}
	kill keys
	set iter = node.%GetIterator()
	while iter.%GetNext(.key) { set keys(" "_key) = "" }
	set out = "{", key = "", first = 1
	for {
		set key = $order(keys(key))
		quit:key=""
		set name = $extract(key, 2, *)
		set out = out _ $select(first:"", 1:",") _ ..Scalar(name) _ ":" _ ..Value(node, name, node.%Get(name)), first = 0
	}
	quit out _ "}"
}

ClassMethod Value(container, key, value) As %String
{
	if $isobject(value) quit ..Canonical(value)
	set type = container.%GetTypeOf(key)
	if type = "boolean" quit $select(value:"true", 1:"false")
	if type = "null" quit "null"
	if type = "number" quit +value
	quit ..Scalar(value)
}

ClassMethod Scalar(value) As %String
{
	quit """" _ $zconvert(value, "O", "JSON") _ """"
}

ClassMethod Hex(bytes As %String) As %String
{
	set out = ""
	for i=1:1:$length(bytes) { set out = out _ $translate($justify($zhex($ascii(bytes, i)), 2), " ", "0") }
	quit $zconvert(out, "L")
}

}

function Get-ParamType{
    param(
        $value
    )
    #get correct name for each value type: object, array, string, int
    $type = $value.GetType().Name
    switch ($type) {
        "String" {
            $type = "string"
        }
        "Int32" {
            $type = "int"
        }
        "Object[]" {
            $type = "array"
        }
        "Object" {
            $type = "object"
        }
        "Hashtable" {
            $type = "object"
        }
        "Boolean" {
            $type = "bool"
        }
        default {
            $type = "string"
        }
    }
    return $type
}
abstract type AbstractApiType end

struct ApiType <: AbstractApiType
    name::String
    docstring::String
    members::OrderedDict{String, DataType}
end

ApiType(; name="unknown", docstring="unknown", members=OrderedDict()) =
    ApiType(name, docstring, members)

StructTypes.StructType(::Type{ApiType}) = StructTypes.Mutable()
ApiType(name, docstring) = ApiType(name, docstring, OrderedDict{String, String}())

function check_key(api_type::ApiType, key)
    type = get(api_type.members, key, nothing)
    if isnothing(type)
        throw(InvalidApiKey("$(api_type.name) does not contain a type called $key"))
    end
    return type
end

function list_keys(api_type::ApiType)
    return collect(keys(api_type.members))
end

struct InvalidApiKey <: Exception
    msg::AbstractString
end

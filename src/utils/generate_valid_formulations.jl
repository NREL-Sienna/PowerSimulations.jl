"""
Generate valid combinations of device_type/formulation and service_type/formulation.
Return vectors of dictionaries with Julia types.

# Arguments

  - `sys::Union{Nothing, System}`: If set, only include component types present in the system.
"""
function generate_formulation_combinations(sys = nothing)
    combos = Dict(
        "device_formulations" => generate_device_formulation_combinations(),
        "service_formulations" => generate_service_formulation_combinations(),
    )

    filter_formulation_combinations!(combos, sys)
    return combos
end

filter_formulation_combinations!(combos, ::Nothing) = nothing

function filter_formulation_combinations!(combos, sys::PSY.System)
    device_types = Set(PSY.get_existing_device_types(sys))
    service_types =
        Set((x for x in PSY.get_existing_component_types(sys) if x <: PSY.Service))
    filter!(x -> x["device_type"] in device_types, combos["device_formulations"])
    filter!(x -> x["service_type"] in service_types, combos["service_formulations"])
end

"""
Generate valid combinations of device_type/formulation and service_type/formulation.
Return vectors of dictionaries with Julia types encoded as strings.

# Arguments

  - `sys::Union{Nothing, System}`: If set, only include component types present in the system.
"""
function serialize_formulation_combinations(sys = nothing)
    combos = generate_formulation_combinations(sys)
    for (i, combo) in enumerate(combos["device_formulations"])
        for key in keys(combo)
            combos["device_formulations"][i][key] = string(nameof(combo[key]))
        end
    end
    for (i, combo) in enumerate(combos["service_formulations"])
        for key in keys(combo)
            combos["service_formulations"][i][key] = string(nameof(combo[key]))
        end
    end

    sort!(combos["device_formulations"]; by = x -> x["device_type"])
    sort!(combos["service_formulations"]; by = x -> x["service_type"])
    return combos
end

"""
Generate valid combinations of device_type/formulation and service_type/formulation and write
the result to a JSON file.

# Arguments

  - `sys::Union{Nothing, System}`: If set, only include component types present in the system.
"""
function write_formulation_combinations(filename::AbstractString, sys = nothing)
    open(filename, "w") do io
        JSON3.pretty(io, serialize_formulation_combinations(sys))
    end
    @info(" to $filename")
end

function generate_device_formulation_combinations()
    combos = []
    for (d, f) in Iterators.product(
        IS.get_all_concrete_subtypes(PSY.Device),
        IS.get_all_concrete_subtypes(AbstractDeviceFormulation),
    )
        # DynamicBranches are not supported in PSI but they are still considered <: PSY.Device since in 
        # PSY 1.0 we haven't introduced the notion of AbstractDynamicBranches. 
        if d <: PSY.DynamicBranch
            continue
        end
        if !isempty(methodswith(DeviceModel{d, f}, construct_device!; supertypes = true))
            push!(combos, Dict{String, Any}("device_type" => d, "formulation" => f))
        end
    end

    return combos
end

function generate_service_formulation_combinations()
    combos = []
    for (d, f) in Iterators.product(
        IS.get_all_concrete_subtypes(PSY.Service),
        IS.get_all_concrete_subtypes(AbstractServiceFormulation),
    )
        if !isempty(methodswith(ServiceModel{d, f}, construct_service!; supertypes = true))
            push!(combos, Dict{String, Any}("service_type" => d, "formulation" => f))
        end
    end

    return combos
end

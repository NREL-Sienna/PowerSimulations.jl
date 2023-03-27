function _check_pm_formulation(::Type{T}) where {T <: PM.AbstractPowerModel}
    if !isconcretetype(T)
        throw(
            ArgumentError(
                "The device model must contain only concrete types, $(T) is an Abstract Type",
            ),
        )
    end
end

"""
Establishes the model for a particular device specified by type.

# Arguments

-`::Type{T}`: PowerModels AbstractPowerModel

# Accepted Key Words

  - `use_slacks::Bool`: Adds slacks to the network modelings
  - `PTDF::PTDF`: PTDF Array calculated using PowerNetworkMatrices
  - `duals::Vector{DataType}`: Constraint types to calculate the duals

# Example

ptdf_array = PTDF(system)
thermal_gens = NetworkModel(StandardPTDFModel, ptdf = ptdf_array),
"""
mutable struct NetworkModel{T <: PM.AbstractPowerModel}
    use_slacks::Bool
    PTDF_matrix::Union{Nothing, PNM.PowerNetworkMatrix}
    subnetworks::Dict{Int, Set{Int}}
    bus_area_map::Dict{PSY.Bus, Int}
    duals::Vector{DataType}

    function NetworkModel(
        ::Type{T};
        use_slacks=false,
        PTDF_matrix=nothing,
        subnetworks=Dict{Int, Set{Int}}(),
        duals=Vector{DataType}(),
    ) where {T <: PM.AbstractPowerModel}
        _check_pm_formulation(T)
        new{T}(use_slacks, PTDF_matrix, subnetworks, Dict{PSY.Bus, Int}(), duals)
    end
end

get_use_slacks(m::NetworkModel) = m.use_slacks
get_PTDF_matrix(m::NetworkModel) = m.PTDF_matrix
get_duals(m::NetworkModel) = m.duals
get_network_formulation(::NetworkModel{T}) where {T <: PM.AbstractPowerModel} = T
get_reference_buses(m::NetworkModel{T}) where {T <: PM.AbstractPowerModel} =
    collect(keys(m.subnetworks))

function add_dual!(model::NetworkModel, dual)
    dual in model.duals && error("dual = $dual is already stored")
    push!(model.duals, dual)
    @debug "Added dual" dual _group = LOG_GROUP_NETWORK_CONSTRUCTION
    return
end

function assign_subnetworks_to_buses(
    model::NetworkModel{StandardPTDFModel},
    sys::PSY.System,
) where {T <: PM.AbstractPowerModel}
    subnetworks = model.subnetworks
    temp_bus_map = Dict{Int, Int}()
    for d in PSY.get_components(T, sys)
        arc = PSY.get_arc(d)
        bus_from = PSY.get_from(arc)
        bus_to = PSY.get_to(arc)
        for bus in (bus_from, bus_to)
            bus_no = PSY.get_number(bus)
            if haskey(temp_bus_map, bus_no)
                model.bus_area_map[bus] = temp_bus_map[bus_no]
            else
                for (subnet, bus_set) in subnetworks
                    if bus_no ∈ bus_set
                        temp_bus_map[bus_no] = subnet
                        model.bus_area_map[bus] = subnet
                        break
                    end
                end
            end
        end
    end
    return
end

assign_subnetworks_to_buses(
    ::NetworkModel{T},
    ::PSY.System,
) where {T <: PM.AbstractPowerModel} = nothing

function get_reference_bus(
    model::NetworkModel{T},
    b::PSY.Bus,
)::Int where {T <: PM.AbstractPowerModel}
    if isempty(model.bus_area_map)
        return first(keys(model.subnetworks))
    else
        return bus_area_map[b]
    end
end

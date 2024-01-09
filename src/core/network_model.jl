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
    bus_area_map::Dict{PSY.ACBus, Int}
    duals::Vector{DataType}
    radial_branches::PNM.RadialBranches
    reduce_radial_branches::Bool
    powerflow_evaluation::Union{Nothing, PFS.PowerFlowEvaluationModel}

    function NetworkModel(
        ::Type{T};
        use_slacks = false,
        PTDF_matrix = nothing,
        reduce_radial_branches = false,
        subnetworks = Dict{Int, Set{Int}}(),
        duals = Vector{DataType}(),
        powerflow_evaluation = nothing
    ) where {T <: PM.AbstractPowerModel}
        _check_pm_formulation(T)
        new{T}(
            use_slacks,
            PTDF_matrix,
            subnetworks,
            Dict{PSY.ACBus, Int}(),
            duals,
            PNM.RadialBranches(),
            reduce_radial_branches,
            powerflow_evaluation
        )
    end
end

get_use_slacks(m::NetworkModel) = m.use_slacks
get_PTDF_matrix(m::NetworkModel) = m.PTDF_matrix
get_reduce_radial_branches(m::NetworkModel) = m.reduce_radial_branches
get_radial_branches(m::NetworkModel) = m.radial_branches
get_duals(m::NetworkModel) = m.duals
get_network_formulation(::NetworkModel{T}) where {T} = T
get_reference_buses(m::NetworkModel{T}) where {T <: PM.AbstractPowerModel} =
    collect(keys(m.subnetworks))
get_subnetworks(m::NetworkModel) = m.subnetworks
get_bus_area_map(m::NetworkModel) = m.bus_area_map
get_powerflow_evaluation(m::NetworkModel) = m.powerflow_evaluation
has_subnetworks(m::NetworkModel) = !isempty(m.bus_area_map)

function add_dual!(model::NetworkModel, dual)
    dual in model.duals && error("dual = $dual is already stored")
    push!(model.duals, dual)
    @debug "Added dual" dual _group = LOG_GROUP_NETWORK_CONSTRUCTION
    return
end

function instantiate_network_model(
    model::NetworkModel{T},
    sys::PSY.System,
) where {T <: PM.AbstractPowerModel}
    if isempty(model.subnetworks)
        model.subnetworks = PNM.find_subnetworks(sys)
    end
    if model.reduce_radial_branches
        model.radial_branches = PNM.RadialBranches(sys)
    end
    return
end

function instantiate_network_model(
    model::NetworkModel{CopperPlatePowerModel},
    sys::PSY.System,
)
    if isempty(model.subnetworks)
        model.subnetworks = PNM.find_subnetworks(sys)
    end

    if length(model.subnetworks) > 1
        @debug "System Contains Multiple Subnetworks. Assigning buses to subnetworks."
        _assign_subnetworks_to_buses(model, sys)
    end
    return
end

function instantiate_network_model(model::NetworkModel{StandardPTDFModel}, sys::PSY.System)
    if get_PTDF_matrix(model) === nothing
        @info "PTDF Matrix not provided. Calculating using PowerNetworkMatrices.PTDF"
        model.PTDF_matrix =
            PNM.PTDF(sys; reduce_radial_branches = model.reduce_radial_branches)
    end
    get_PTDF_matrix(model).subnetworks
    model.subnetworks = deepcopy(get_PTDF_matrix(model).subnetworks)
    if length(model.subnetworks) > 1
        @debug "System Contains Multiple Subnetworks. Assigning buses to subnetworks."
        _assign_subnetworks_to_buses(model, sys)
    end
    if model.reduce_radial_branches
        @assert !isempty(model.PTDF_matrix.radial_branches)
        model.radial_branches = model.PTDF_matrix.radial_branches
    end
    return
end

function _assign_subnetworks_to_buses(
    model::NetworkModel{T},
    sys::PSY.System,
) where {T <: Union{CopperPlatePowerModel, StandardPTDFModel}}
    subnetworks = model.subnetworks
    temp_bus_map = Dict{Int, Int}()
    for bus in get_available_components(PSY.ACBus, sys)
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
    return
end

_assign_subnetworks_to_buses(
    ::NetworkModel{T},
    ::PSY.System,
) where {T <: PM.AbstractPowerModel} = nothing

function get_reference_bus(
    model::NetworkModel{T},
    b::PSY.ACBus,
)::Int where {T <: PM.AbstractPowerModel}
    if isempty(model.bus_area_map)
        return first(keys(model.subnetworks))
    else
        return model.bus_area_map[b]
    end
end

function _check_pm_formulation(::Type{T}) where {T <: PM.AbstractPowerModel}
    if !isconcretetype(T)
        throw(
            ArgumentError(
                "The network model must contain only concrete types, $(T) is an Abstract Type",
            ),
        )
    end
end

"""
Establishes the model for the network specified by type.

# Arguments

-`::Type{T}`: PowerModels AbstractPowerModel

# Accepted Key Words

  - `use_slacks::Bool`: Adds slacks to the network modeling
  - `PTDF::PTDF`: PTDF Array calculated using PowerNetworkMatrices
  - `duals::Vector{DataType}`: Constraint types to calculate the duals
  - `reduce_radial_branches::Bool`: Skips modeling radial branches in the system to reduce problem size
# Example

ptdf_array = PTDF(system)
nw = NetworkModel(PTDFPowerModel, ptdf = ptdf_array),
"""
mutable struct NetworkModel{T <: PM.AbstractPowerModel}
    use_slacks::Bool
    PTDF_matrix::Union{Nothing, PNM.PowerNetworkMatrix}
    subnetworks::Dict{Int, Set{Int}}
    bus_area_map::Dict{PSY.ACBus, Int}
    duals::Vector{DataType}
    radial_network_reduction::PNM.RadialNetworkReduction
    reduce_radial_branches::Bool
    subsystem::Union{Nothing, String}
    modeled_branch_types::Vector{DataType}

    function NetworkModel(
        ::Type{T};
        use_slacks = false,
        PTDF_matrix = nothing,
        reduce_radial_branches = false,
        subnetworks = Dict{Int, Set{Int}}(),
        duals = Vector{DataType}(),
    ) where {T <: PM.AbstractPowerModel}
        _check_pm_formulation(T)
        new{T}(
            use_slacks,
            PTDF_matrix,
            subnetworks,
            Dict{PSY.ACBus, Int}(),
            duals,
            PNM.RadialNetworkReduction(),
            reduce_radial_branches,
            nothing,
            Vector{DataType}(),
        )
    end
end

get_use_slacks(m::NetworkModel) = m.use_slacks
get_PTDF_matrix(m::NetworkModel) = m.PTDF_matrix
get_reduce_radial_branches(m::NetworkModel) = m.reduce_radial_branches
get_radial_network_reduction(m::NetworkModel) = m.radial_network_reduction
get_duals(m::NetworkModel) = m.duals
get_network_formulation(::NetworkModel{T}) where {T} = T
get_reference_buses(m::NetworkModel{T}) where {T <: PM.AbstractPowerModel} =
    collect(keys(m.subnetworks))
get_subnetworks(m::NetworkModel) = m.subnetworks
get_bus_area_map(m::NetworkModel) = m.bus_area_map
has_subnetworks(m::NetworkModel) = !isempty(m.bus_area_map)
get_subsystem(m::NetworkModel) = m.subsystem

set_subsystem!(m::NetworkModel, id::String) = m.subsystem = id

function add_dual!(model::NetworkModel, dual)
    dual in model.duals && error("dual = $dual is already stored")
    push!(model.duals, dual)
    @debug "Added dual" dual _group = LOG_GROUP_NETWORK_CONSTRUCTION
    return
end

function check_radial_branch_reduction_compatibility(
    ::Type{T},
) where {T <: PM.AbstractPowerModel}
    if T ∈ INCOMPATIBLE_WITH_RADIAL_BRANCHES_POWERMODELS
        error("Network Model $T is not compatible with radial branch reduction")
    end
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
        check_radial_branch_reduction_compatibility(T)
        model.radial_network_reduction = PNM.RadialNetworkReduction(sys)
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

function instantiate_network_model(
    model::NetworkModel{<:AbstractPTDFModel},
    sys::PSY.System,
)
    if get_PTDF_matrix(model) === nothing
        @info "PTDF Matrix not provided. Calculating using PowerNetworkMatrices.PTDF"
        model.PTDF_matrix =
            PNM.PTDF(sys; reduce_radial_branches = model.reduce_radial_branches)
    end
    if model.reduce_radial_branches
        @assert !isempty(model.PTDF_matrix.radial_network_reduction)
        model.radial_network_reduction = model.PTDF_matrix.radial_network_reduction
    end
    get_PTDF_matrix(model).subnetworks
    model.subnetworks = deepcopy(get_PTDF_matrix(model).subnetworks)
    if length(model.subnetworks) > 1
        @debug "System Contains Multiple Subnetworks. Assigning buses to subnetworks."
        _assign_subnetworks_to_buses(model, sys)
    end
    return
end

function _assign_subnetworks_to_buses(
    model::NetworkModel{T},
    sys::PSY.System,
) where {T <: Union{CopperPlatePowerModel, AbstractPTDFModel}}
    subnetworks = model.subnetworks
    temp_bus_map = Dict{Int, Int}()
    radial_network_reduction = PSI.get_radial_network_reduction(model)
    for bus in PSI.get_available_components(model, PSY.ACBus, sys)
        bus_no = PSY.get_number(bus)
        mapped_bus_no = PNM.get_mapped_bus_number(radial_network_reduction, bus)
        if haskey(temp_bus_map, bus_no)
            model.bus_area_map[bus] = temp_bus_map[bus_no]
            continue
        else
            bus_mapped = false
            for (subnet, bus_set) in subnetworks
                if mapped_bus_no ∈ bus_set
                    temp_bus_map[bus_no] = subnet
                    model.bus_area_map[bus] = subnet
                    bus_mapped = true
                    break
                end
            end
        end
        if !bus_mapped
            error("Bus $(PSY.summary(bus)) not mapped to any reference bus")
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

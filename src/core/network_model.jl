const REDUCED_BRANCH_VARIABLE_DICT = Dict{
    Type{<:PSY.ACTransmission},
    Dict{
        Type{<:ISOPT.VariableType},
        Dict{String, Dict{Int, JuMP.VariableRef}},
    },
}
const REDUCED_BRANCH_CONSTRAINT_DICT =
    Dict{
        Type{<:PSY.ACTransmission},
        Dict{Type{<:ISOPT.ConstraintType}, Vector{String}},
    }

function _check_pm_formulation(::Type{T}) where {T <: PM.AbstractPowerModel}
    if !isconcretetype(T)
        throw(
            ArgumentError(
                "The network model must contain only concrete types, $(T) is an Abstract Type",
            ),
        )
    end
end

_maybe_flatten_pfem(pfem::Vector{PFS.PowerFlowEvaluationModel}) = pfem
_maybe_flatten_pfem(pfem::PFS.PowerFlowEvaluationModel) =
    PFS.flatten_power_flow_evaluation_model(pfem)

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
    network_reduction::PNM.NetworkReductionData
    reduce_radial_branches::Bool
    reduce_degree_two_branches::Bool
    power_flow_evaluation::Vector{PFS.PowerFlowEvaluationModel}
    subsystem::Union{Nothing, String}
    modeled_branch_types::Vector{DataType}
    reduced_branch_variable_tracker::REDUCED_BRANCH_VARIABLE_DICT
    reduced_branch_constraint_tracker::REDUCED_BRANCH_CONSTRAINT_DICT

    function NetworkModel(
        ::Type{T};
        use_slacks = false,
        PTDF_matrix = nothing,
        reduce_radial_branches = false,
        reduce_degree_two_branches = false,
        subnetworks = Dict{Int, Set{Int}}(),
        duals = Vector{DataType}(),
        power_flow_evaluation::Union{
            PFS.PowerFlowEvaluationModel,
            Vector{PFS.PowerFlowEvaluationModel},
        } = PFS.PowerFlowEvaluationModel[],
    ) where {T <: PM.AbstractPowerModel}
        _check_pm_formulation(T)
        new{T}(
            use_slacks,
            PTDF_matrix,
            subnetworks,
            Dict{PSY.ACBus, Int}(),
            duals,
            PNM.NetworkReductionData(),
            reduce_radial_branches,
            reduce_degree_two_branches,
            _maybe_flatten_pfem(power_flow_evaluation),
            nothing,
            Vector{DataType}(),
            REDUCED_BRANCH_VARIABLE_DICT(),
            REDUCED_BRANCH_CONSTRAINT_DICT(),
        )
    end
end

get_use_slacks(m::NetworkModel) = m.use_slacks
get_PTDF_matrix(m::NetworkModel) = m.PTDF_matrix
get_reduce_radial_branches(m::NetworkModel) = m.reduce_radial_branches
get_network_reduction(m::NetworkModel) = m.network_reduction
get_duals(m::NetworkModel) = m.duals
get_network_formulation(::NetworkModel{T}) where {T} = T
get_reference_buses(m::NetworkModel{T}) where {T <: PM.AbstractPowerModel} =
    collect(keys(m.subnetworks))
get_subnetworks(m::NetworkModel) = m.subnetworks
get_bus_area_map(m::NetworkModel) = m.bus_area_map
get_power_flow_evaluation(m::NetworkModel) = m.power_flow_evaluation
has_subnetworks(m::NetworkModel) = !isempty(m.bus_area_map)
get_subsystem(m::NetworkModel) = m.subsystem

set_subsystem!(m::NetworkModel, id::String) = m.subsystem = id

function add_dual!(model::NetworkModel, dual)
    dual in model.duals && error("dual = $dual is already stored")
    push!(model.duals, dual)
    @debug "Added dual" dual _group = LOG_GROUP_NETWORK_CONSTRUCTION
    return
end

# TODO - check for incompatibilities between PowerModels and Network reductions
const INCOMPATIBLE_WITH_NETWORK_REDUCTION_POWERMODELS = []

function check_network_reduction_compatibility(
    ::Type{T},
) where {T <: PM.AbstractPowerModel}
    if T ∈ INCOMPATIBLE_WITH_NETWORK_REDUCTION_POWERMODELS
        error("Network Model $T is not compatible with network reduction")
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
    if model.reduce_radial_branches && model.reduce_degree_two_branches
        @info "Applying both radial and degree two reductions"
        ybus = PNM.Ybus(
            sys;
            network_reductions = PNM.NetworkReduction[
                PNM.RadialReduction(),
                PNM.DegreeTwoReduction(),
            ],
        )
    elseif model.reduce_radial_branches
        @info "Applying radial reduction"
        ybus =
            PNM.Ybus(sys; network_reductions = PNM.NetworkReduction[PNM.RadialReduction()])
    elseif model.reduce_degree_two_branches
        @info "Applying degree two reduction"
        ybus = PNM.Ybus(
            sys;
            network_reductions = PNM.NetworkReduction[PNM.DegreeTwoReduction()],
        )
    else
        ybus = PNM.Ybus(sys)
    end
    model.network_reduction = ybus.network_reduction_data
    if !isempty(model.network_reduction)
        check_network_reduction_compatibility(T)
    end
    PNM.populate_branch_maps_by_type!(model.network_reduction)
    return
end

function instantiate_network_model(
    model::NetworkModel{AreaBalancePowerModel},
    sys::PSY.System,
)
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
        if model.reduce_radial_branches && model.reduce_degree_two_branches
            @info "Applying both radial and degree two reductions"
            ptdf = PNM.VirtualPTDF(
                sys;
                network_reductions = PNM.NetworkReduction[
                    PNM.RadialReduction(),
                    PNM.DegreeTwoReduction(),
                ],
            )
        elseif model.reduce_radial_branches
            @info "Applying radial reduction"
            ptdf = PNM.VirtualPTDF(
                sys;
                network_reductions = PNM.NetworkReduction[PNM.RadialReduction()],
            )
        elseif model.reduce_degree_two_branches
            @info "Applying degree two reduction"
            ptdf = PNM.VirtualPTDF(
                sys;
                network_reductions = PNM.NetworkReduction[PNM.DegreeTwoReduction()],
            )
        else
            ptdf = PNM.VirtualPTDF(sys)
        end
        model.PTDF_matrix = ptdf
        model.network_reduction = ptdf.network_reduction_data
    else
        model.network_reduction = model.PTDF_matrix.network_reduction_data
    end

    if !model.reduce_radial_branches && PNM.has_radial_reduction(
        PNM.get_reductions(model.PTDF_matrix.network_reduction_data),
    )
        throw(
            IS.ConflictingInputsError(
                "The provided PTDF Matrix has reduced radial branches and mismatches the network \\
                model specification reduce_radial_branches = false. Set the keyword argument \\
                reduce_radial_branches = true in your network model"),
        )
    end
    if !model.reduce_degree_two_branches && PNM.has_degree_two_reduction(
        PNM.get_reductions(model.PTDF_matrix.network_reduction_data),
    )
        throw(
            IS.ConflictingInputsError(
                "The provided PTDF Matrix has reduced degree two branches and mismatches the network \\
                model specification reduce_degree_two_branches = false. Set the keyword argument \\
                reduce_degree_two_branches = true in your network model"),
        )
    end
    if model.reduce_radial_branches &&
       PNM.has_ward_reduction(PNM.get_reductions(model.PTDF_matrix.network_reduction_data))
        throw(
            IS.ConflictingInputsError(
                "The provided PTDF Matrix has  a ward reduction specified and the keyword argument \\
                reduce_radial_branches = true. Set the keyword argument reduce_radial_branches = false \\
                or provide a modified PTDF Matrix without the Ward reduction."),
        )
    end

    if model.reduce_radial_branches
        @assert !isempty(model.PTDF_matrix.network_reduction_data)
    end
    model.subnetworks = _make_subnetworks_from_subnetwork_axes(model.PTDF_matrix)
    if length(model.subnetworks) > 1
        @debug "System Contains Multiple Subnetworks. Assigning buses to subnetworks."
        _assign_subnetworks_to_buses(model, sys)
    end
    PNM.populate_branch_maps_by_type!(model.network_reduction)
    return
end

function _make_subnetworks_from_subnetwork_axes(ptdf::PNM.PTDF)
    subnetworks = Dict{Int, Set{Int}}()
    for (ref_bus, ptdf_axes) in ptdf.subnetwork_axes
        subnetworks[ref_bus] = Set(ptdf_axes[1])
    end
    return subnetworks
end

function _make_subnetworks_from_subnetwork_axes(ptdf::PNM.VirtualPTDF)
    subnetworks = Dict{Int, Set{Int}}()
    for (ref_bus, ptdf_axes) in ptdf.subnetwork_axes
        subnetworks[ref_bus] = Set(ptdf_axes[2])
    end
    return subnetworks
end

function _assign_subnetworks_to_buses(
    model::NetworkModel{T},
    sys::PSY.System,
) where {T <: Union{CopperPlatePowerModel, AbstractPTDFModel}}
    subnetworks = model.subnetworks
    temp_bus_map = Dict{Int, Int}()
    network_reduction = PSI.get_network_reduction(model)
    for bus in PSI.get_available_components(model, PSY.ACBus, sys)
        bus_no = PSY.get_number(bus)
        mapped_bus_no = PNM.get_mapped_bus_number(network_reduction, bus)
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

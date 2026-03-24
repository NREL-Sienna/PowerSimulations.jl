mutable struct PowerFlowEvaluationData{T <: PFS.PowerFlowContainer}
    power_flow_data::T
    """
    Records which PSI keys are read as input to the power flow and how the data are mapped.
    The Symbol is a category of data: `:active_power`, `:reactive_power`, etc. The
    `OptimizationContainerKey` is a source of that data in the `OptimizationContainer`. For
    `PowerFlowData`, leaf values are `Dict{String, Int64}` mapping component name to matrix
    index of bus; for `SystemPowerFlowContainer`, leaf values are `Dict{String, String}`
    mapping component name to component name.
    """
    input_key_map::Dict{Symbol, <:Dict{<:OptimizationContainerKey, <:Any}}
    "Precomputed bus name → PowerFlowData matrix index mapping (empty for SystemPowerFlowContainer)"
    bus_name_to_ix::Dict{String, Int}
    is_solved::Bool
end

check_network_reduction(::PFS.SystemPowerFlowContainer) = nothing

function check_network_reduction(pfd::PFS.PowerFlowData)
    nrd = PFS.get_network_reduction_data(pfd)
    if !isempty(PNM.get_reductions(nrd))
        throw(
            IS.NotImplementedError(
                "Power flow in-the-loop on reduced networks isn't supported. Network " *
                "reductions of types $(PNM.get_reductions(nrd)) present.",
            ),
        )
    end
    return
end

function PowerFlowEvaluationData(power_flow_data::T) where {T <: PFS.PowerFlowContainer}
    check_network_reduction(power_flow_data)
    return PowerFlowEvaluationData{T}(
        power_flow_data,
        Dict{Symbol, Dict{OptimizationContainerKey, <:Any}}(),
        Dict{String, Int}(),
        false,
    )
end

get_power_flow_data(ped::PowerFlowEvaluationData) = ped.power_flow_data
get_input_key_map(ped::PowerFlowEvaluationData) = ped.input_key_map

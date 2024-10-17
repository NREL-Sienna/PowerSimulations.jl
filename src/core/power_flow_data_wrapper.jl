mutable struct PowerFlowEvaluationData{T <: PFS.PowerFlowContainer}
    power_flow_data::T
    """
    Records which PSI keys get used to update the data and how they are mapped to it. For
    `PowerFlowData`, values are `Dict{String, Int}` specifying component name, matrix index;
    for `SystemPowerFlowContainer`, values are Set{String} merely specifying component
    names.
    """
    injection_key_map::Dict{<:OptimizationContainerKey, <:Any}
    is_solved::Bool
end

function PowerFlowEvaluationData(power_flow_data::T) where {T <: PFS.PowerFlowContainer}
    return PowerFlowEvaluationData{T}(
        power_flow_data,
        Dict{OptimizationContainerKey, Nothing}(),
        false,
    )
end

get_power_flow_data(ped::PowerFlowEvaluationData) = ped.power_flow_data
get_injection_key_map(ped::PowerFlowEvaluationData) = ped.injection_key_map
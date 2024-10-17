mutable struct PowerFlowEvaluationData{T <: PFS.PowerFlowContainer}
    power_flow_data::T
    """
    Records which PSI keys are read as input to the power flow and how the data are mapped.
    For `PowerFlowData`, values are `Dict{String, Int64}` mapping component name to matrix
    index of bus; for `SystemPowerFlowContainer`, values are Dict{Union{String, Int64},
    Union{String, Int64}} mapping component name/bus number to component name/bus number.
    """
    input_key_map::Dict{<:OptimizationContainerKey, <:Any}
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
get_input_key_map(ped::PowerFlowEvaluationData) = ped.input_key_map

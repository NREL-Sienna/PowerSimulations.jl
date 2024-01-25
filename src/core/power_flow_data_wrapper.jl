mutable struct PowerFlowEvaluationData{T <: PFS.PowerFlowData}
    power_flow_data::T
    injection_key_map::Dict{<:OptimizationContainerKey, Dict{String, Int}}
end

function PowerFlowEvaluationData(power_flow_data::T) where {T <: PFS.PowerFlowData}
    return PowerFlowEvaluationData{T}(
        power_flow_data,
        Dict{OptimizationContainerKey, Dict{String, Int}}(),
    )
end

get_power_flow_data(ped::PowerFlowEvaluationData) = ped.power_flow_data
get_injection_key_map(ped::PowerFlowEvaluationData) = ped.injection_key_map

struct OperationModelResults
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict{Symbol,Float64}
    optimizer_log::Dict{Symbol, Any}
end

function get_variable(res_model::OperationModelResults, key::Symbol)
    return get(res_model.variables, key, nothing)
end

function get_optimizer_log(res_model::OperationModelResults)
    return res_model.optimizer_log 
end

function get_times(res_model::OperationModelResults, key::Symbol)
    return res_model.times
end

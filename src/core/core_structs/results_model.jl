struct OpertationModelResults
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict{Symbol,Float64}
    optimizer_log::Dict{Symbol, Any}
end

function get_variable(res_model::OpertationModelResults, key::Symbol)
    return get(res_model.variables, key, nothing)
end

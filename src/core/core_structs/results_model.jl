struct OpertationModelResults
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict{Symbol,Float64}
    optimizer_log::Dict{Symbol, Any}
end

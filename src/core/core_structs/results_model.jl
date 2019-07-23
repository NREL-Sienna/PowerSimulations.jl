struct OpertationModelResults
    variables::Dict{Symbol, DataFrames.DataFrame}
    optimizer_log::Dict{Symbol, Any}
end

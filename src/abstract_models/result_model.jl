mutable struct PowerResults
    variables::Dict{String,DataFrames.DataFrame}
    total_cost::Dict{String,Float64}
    optimizer_output::Dict{String,Any}
end

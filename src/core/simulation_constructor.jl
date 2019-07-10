
function build_simulation!(stages::Dict{Int64, (ModelReference, PSY.System)},
                           executioncount::Dict{Int64,Int64})

    mod_stages = Dict{Int64,OperationModel}()

    for (k,v) in stages
        mod_stages[k] = OperationModel(v[1], v[2]; sequential_runs = true, kwargs...)
    end

end

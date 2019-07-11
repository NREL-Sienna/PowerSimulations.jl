function _prepare_workspace(base_name::String, folder::String)



end

function _get_dates(stages, periods, executioncount)

    date_from, date_to = (0.0, 0.0)

    return date_from, date_to

end

function build_simulation!(stages::Dict{Int64, (ModelReference, PSY.System)},
                           executioncount::Dict{Int64,Int64})

    mod_stages = Dict{Int64,OperationModel}()

    for (k,v) in stages
        mod_stages[k] = OperationModel(v[1], v[2]; sequential_runs = true, kwargs...)
    end

end



function PowerSimulationsModel(simulation_folder::String,
                                base_name::String,
                                periods::Int64,
                                stages::Dict{Int64, (ModelReference, PSY.System)},
                                executioncount::Dict{Int64, Int64},
                                feedback_ref;
                                kwargs...)

    _prepare_workspace(base_name,simulation_folder)

    op_stages = build_simulation!(stages, executioncount; kwargs...)

    date_from, date_to = _get_dates(stages, periods, executioncount)

    new(base_name,
        periods,
        op_stages,
        executioncount,
        feedback_ref,
        date_from,
        date_to)

end
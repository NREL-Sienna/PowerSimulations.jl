mutable struct PowerSimulationsModel
    base_name::String
    periods::Int64
    stages::Dict{Int64,OperationModel}
    executioncount::Dict{Int64,Int64}
    feedback_ref::Any
    date_from::Dates.DateTime
    date_to::Dates.DateTime
    simulation_folder::String
end

function _prepare_workspace(base_name::String, folder::String)



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

    date_from, date_to = get_dates(stages, periods, executioncount)

    new(name,
        periods,
        op_stages,
        executioncount,
        feedback_ref,
        date_from,
        date_to)

end
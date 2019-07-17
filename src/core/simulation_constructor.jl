function _prepare_workspace(base_name::String, folder::String)



end

function _get_dates(stages::Dict{Int64, Tuple{M, PSY.System, Int64}}) where {M<:ModelReference}
    k = keys(stages)
    k_size = length(k)
    range = Vector{Dates.DateTime}(undef, 2)
    @assert k_size == maximum(k)

    for i in 1:k_size
        initial_times = PSY.get_forecast_initial_times(stages[i][2])
        i == 1 && (range[1] = initial_times[1])
        interval = PSY.get_forecasts_interval(stages[i][2])
        for (ix,element) in enumerate(initial_times[1:end-1])
            @assert element + interval == initial_times[ix+1]
        end
        i == k_size && (range[end] = initial_times[end])
    end

    return range, true

end

#=
function build_simulation!(stages::Dict{Int64, Any}, executioncount::Dict{Int64, Int64}; kwargs...)

    mod_stages = Dict{Int64, OperationModel}()

    for (k, v) in stages
        mod_stages[k] = OperationModel(v[1], v[2]; sequential_runs = true; kwargs...)
    end

end



function PowerSimulationsModel(simulation_folder::String,
                                basename::String,
                                steps::Int64,
                                stages::Dict{Int64, Tuple{ModelReference, PSY.System, Int64}}),
                                executioncount::Dict{Int64, Int64},
                                feedback_ref;
                                kwargs...)

    _prepare_workspace(basename, simulation_folder)

    #op_stages = build_simulation!(stages, executioncount; kwargs...)

    date_from, date_to = _get_dates(stages, steps, executioncount)

    new(basename,
        steps,
        stages,
        feedback_ref,
        date_from,
        date_to)

end
=#

function _prepare_workspace(base_name::String, folder::String)

    !isdir(folder) && error("Specified folder is not valid")

    cd(folder)
    simulation_path = joinpath(folder, "$(Dates.today())-$(base_name)")
    mkpath(joinpath(simulation_path, "raw_output"))

    return

end

function _validate_steps(stages::Dict{Int64, Tuple{ModelReference{T}, PSY.System, Int64}},
                         steps::Int64) where {T <: PM.AbstractPowerFormulation}

    for (k,v) in stages

        forecast_count = length(PSY.get_forecast_initial_times(v[2]))

        if steps*v[3] > forecast_count #checks that there are enough time series to run
            error("The number of available time series is not enough to perform the
                   desired amount of simulation steps.")
        end

    end

    return

end

function _get_dates(stages::Dict{Int64, Tuple{ModelReference{T}, PSY.System, Int64}}) where {T <: PM.AbstractPowerFormulation}
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
=#


function PowerSimulationsModel(simulation_folder::String,
                               basename::String,
                               steps::Int64,
                               stages::Dict{Int64, Any},
                               feedback_ref;
                               kwargs...) where {M<:ModelReference}


    _validate_steps(stages, steps)

    _prepare_workspace(basename, simulation_folder)



    dates, validation = _get_dates(stages)

    new(basename,
        steps,
        stages,
        feedback_ref,
        validation,
        dates[1],
        dates[2])

end

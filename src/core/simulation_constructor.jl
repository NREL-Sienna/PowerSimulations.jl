function _prepare_workspace!(ref::SimulationRef, base_name::String, folder::String)

    !isdir(folder) && error("Specified folder is not valid")

    cd(folder)
    simulation_path = joinpath(folder, "$(Dates.today())-$(base_name)")
    raw_ouput = joinpath(simulation_path, "raw_output")
    mkpath(raw_ouput)
    ref.raw = raw_ouput

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
            if !(element + interval == initial_times[ix+1])
                error("The sequence of forecasts is invalid")
            end
        end
        (i == k_size && (range[end] = initial_times[end]))
    end

    return Tuple(range), true

end

function _build_stages(stages::Dict{Int64, Tuple{ModelReference{T}, PSY.System, Int64}}; kwargs...) where {T<:PM.AbstractPowerFormulation}

    mod_stages = Vector{Stage}(undef, length(stages))

    for (k, v) in stages
        op_mod = OperationModel(DefaultOpModel, v[1], v[2]; sequential_runs = true, kwargs...)
        mod_stages[k] = Stage(k, op_mod, v[3])
    end

    return mod_stages

end

function build_simulation!(sim_ref::SimulationRef,
                          base_name::String,
                          steps::Int64,
                          stages::Dict{Int64, Tuple{ModelReference{T}, PSY.System, Int64}},
                          feedback_ref,
                          simulation_folder::String;
                          kwargs...) where {T<:PM.AbstractPowerFormulation}


    _validate_steps(stages, steps)
    dates, validation = _get_dates(stages)
    _prepare_workspace!(sim_ref, base_name, simulation_folder)

    return dates, validation, _build_stages(stages)

end

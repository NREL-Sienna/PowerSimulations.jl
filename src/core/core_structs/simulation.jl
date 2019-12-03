mutable struct SimulationRef
    raw::String
    models::String
    results::String
    run_count::Dict{Int64, Dict{Int64, Int64}}
    date_ref::Dict{Int64, Dates.DateTime}
    current_time::Dates.DateTime
    reset::Bool
    daterange::NTuple{2, Dates.DateTime} #Inital Time of the first forecast and Inital Time of the last forecast
end

function _initialize_sim_ref(steps::Int64, stages_keys::Base.KeySet)
    count_dict = Dict{Int64, Dict{Int64, Int64}}()

    for s in 1:steps
        count_dict[s] = Dict{Int64, Int64}()
        for st in stages_keys
            count_dict[s][st] = 0
        end
    end

    return sim_ref = SimulationRef(
                                  "init",
                                   "init",
                                   "init",
                                   count_dict,
                                   Dict{Int64, Dates.DateTime}(),
                                   Dates.now(),
                                   true
                                   )
end

mutable struct Simulation
    steps::Int64
    stages::Dict{Int64, Stage{<:AbstractOperationsProblem}}
    #ref::SimulationRef
    simulation_folder::String
    name::String
    compiled_status::Bool

    function Simulation(;name::String,
                        steps::Int64,
                        stages=Dict{Int64, Stage{AbstractOperationsProblem}}(),
                        simulation_folder::String,
                        verbose::Bool = false, kwargs...)

    #sim_ref = _initialize_sim_ref(steps, keys(stages))
    #dates, validation, stages_vector = _build_simulation!(
    #                                                      sim_ref,
    #                                                      steps,
    #                                                      stages;
    #                                                      verbose = verbose, kwargs...
    #                                                      )
    #@assert sim_ref.raw != "init"
    #@assert sim_ref.models != "init"
    #@assert sim_ref.results != "init"

    new(
        steps,
        stages,
        simulation_folder,
        name,
        false
        )
    end
end

################# accessor functions ####################
get_steps(s::Simulation) = s.steps
#get_daterange(s::Simulation) = s.daterange

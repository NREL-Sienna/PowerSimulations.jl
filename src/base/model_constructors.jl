function buildmodel!(op_model::PowerOperationModel, sys::PSY.PowerSystem; kwargs...)

    #TODO: Add check model spec vs data functions before trying to build

    netinjection = instantiate_network(op_model.transmission, sys)

    for category in op_model.generation
        construct_device!(op_model.model, netinjection, category.device, category.formulation, op_model.transmission, sys; kwargs...)
    end

    if op_model.demand != nothing
        for category in op_model.demand
            construct_device!(op_model.model, netinjection, category.device, category.formulation, op_model.transmission, sys; kwargs...)
        end
    end

    #=
    for category in op_model.storage
        op_model.model = construct_device!(category.device, network_model, op_model.model, devices_netinjection, sys, category.constraints)
    end
    =#
    if op_model.services != nothing
        service_providers = Array{NamedTuple{(:device, :formulation),Tuple{DataType,DataType}}}([])
        [push!(service_providers,x) for x in vcat(op_model.generation,op_model.demand,op_model.storage) if x != nothing]
        for service in op_model.services
            op_model.model = constructservice!(op_model.model, service.service, service.formulation, service_providers, sys; kwargs...)
        end
    end

    constructnetwork!(op_model.model, op_model.branches, netinjection, op_model.transmission, sys; args..., PTDF = op_model.ptdf)

    JuMP.@objective(op_model.model, Min, op_model.model.obj_dict[:objective_function])

   return op_model

end


function build_sim_ts(ts_dict::Dict{String,Any}, steps, periods, resolution, date_from, lookahead_periods, lookahead_resolution ; kwargs...)
    # exmaple of time series assembly
    # TODO: once we refactor PowerSystems, we can improve this process

    steps_dict = Dict()

    function _subset_ts(ts_dict,start,finish)
        return ts_dict[(ts_dict.DateTime .>= start) .& (ts_dict.DateTime .< finish),:]
    end

    for step in 1:steps
        step_stamp = date_from + ((resolution * periods) + (lookahead_periods * lookahead_resolution)) * (step-1)
        step_end = step_stamp + (resolution * periods) + (lookahead_periods * lookahead_resolution)
        steps_dict[step_stamp] = deepcopy(ts_dict)
        steps_dict[step_stamp]["load"] = _subset_ts(steps_dict[step_stamp]["load"],step_stamp,step_end)
        for cat in keys(steps_dict[step_stamp]["gen"])
            steps_dict[step_stamp]["gen"][cat] = _subset_ts(steps_dict[step_stamp]["gen"][cat],step_stamp,step_end)
        end
    end

    return steps_dict
end


function buildsimulation!(sys::PSY.PowerSystem, op_model::PowerOperationModel, ts_dict::Dict{String,Any}; kwargs...)

    name = :name in keys(args) ? args[:name] : "my_simulation"

    model = op_model

    resolution = :resolution in keys(args) ? args[:resolution] : PSY.getresolution(sys.loads[1].scalingfactor)

    date_from = :date_from in keys(args) ? args[:date_from] : minimum(timestamp(sys.loads[1].scalingfactor))

    date_to = :date_to in keys(args) ? args[:date_to] : maximum(timestamp(sys.loads[1].scalingfactor))

    periods = :periods in keys(args) ? args[:periods] : (resolution < Hour(1) ? 1 : 24)

    steps = :steps in keys(args) ? args[:steps] : Int64(floor((length(sys.loads[1].scalingfactor)-1)/periods))

    if steps != (length(sys.loads[1].scalingfactor)-1)/periods
        @warn "Time series length and simulation definiton inconsistent, simulation may be truncated, simulating $steps stePSI."
    end

    lookahead_periods = :lookahead_periods in keys(args) ? args[:lookahead_periods] : 0

    lookahead_resolution = :lookahead_resolution in keys(args) ? args[:lookahead_resolution] : resolution

    @info "Simulation defined for $steps steps with $periods * $resolution periods per step (plus $lookahead_periods * $lookahead_resolution lookahead periods), from $date_from to $date_to"

    dynamic_analysis = false;

    timeseries = build_sim_ts(ts_dict, steps, periods, resolution, date_from, lookahead_periods, lookahead_resolution ; kwargs...)

    PowerSimulationsModel(name,model, steps, periods, resolution, date_from, date_to,
            lookahead_periods, lookahead_resolution, dynamic_analysis, timeseries)

end

function buildsimulation!(sys::PSY.PowerSystem, op_model::PowerOperationModel; kwargs...)

    ts_dict = Dict{String,Any}()

    ts_dict["load"] = DataFrame(Dict([(l.name,values(l.scalingfactor)) for l in sys.loads]))
    ts_dict["load"][:DateTime] = TimeSeries.timestamp(sys.loads[1].scalingfactor)

    ts_dict["gen"] = Dict()

    if !isa(sys.generators.renewable,Nothing)
        # TODO: do a better job of classifying generators in the timeseries dict and reflect that here. For now, i'm just using PV as a placeholder
        ts_dict["gen"]["PV"] = DataFrame(Dict([(g.name,values(g.scalingfactor)) for g in sys.generators.renewable]))
        ts_dict["gen"]["PV"][:DateTime] = timestamp(sys.generators.renewable[1].scalingfactor)
        ts_dict["gen"]["WIND"] = DataFrame(Dict([(g.name,values(g.scalingfactor)) for g in sys.generators.renewable]))
        ts_dict["gen"]["WIND"][:DateTime] = timestamp(sys.generators.renewable[1].scalingfactor)
    end

    if !isa(sys.generators.hydro,Nothing)
        ts_dict["gen"]["Hydro"] = DataFrame(Dict([(g.name,values(g.scalingfactor)) for g in sys.generators.hydro]))
        ts_dict["gen"]["Hydro"][:DateTime] = timestamp(sys.generators.hydro[1].scalingfactor)
    end

    buildsimulation!(sys, op_model, ts_dict; kwargs...)
end


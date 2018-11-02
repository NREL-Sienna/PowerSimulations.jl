export simulatemodel

function modify_constraint(m::JuMP.Model, consname::Symbol, data::Array{Float64,2})

    !(size(m[consmane]) == size(data)) ? error("The data and the constraint are size inconsistent") : true

    for (n, c) in enumerate(IndexCartesian(), data)

        JuMP.setRHS(m[consname], data[n])

    end

    return m

end

function run_simulations(simulation::PowerSimulationsModel{S}, solver, ps_dict::Dict; args...) where {S<:AbstractOperationsModel}
    # TODO: refactor system to be mutable and remove ps_dict from arguments

    # CheckPowerModel(m::PowerSimulationsModel{T}) where T<:AbstractPowerSimulationType
    # AssignSolver(m::PowerSimulationsModel{T}) where T<:AbstractPowerSimulationType
    # WarmUpModel(m::PowerSimulationsModel{T}) where T<:AbstractPowerSimulationType

    # Precalculate PTDF and initialize generator statuses

    sys = simulation.system

    if simulation.transmission <: AbstractFlowForm
        PTDF,  A = PowerSystems.buildptdf(sys.branches, sys.buses)
    else
        PTDF = nothing
    end

    name_index = [gen.name for gen in sys.generators.thermal];

    initialpowerdict = :initialpowerdict in keys(args) ? args[:initialpowerdict] : Dict(zip(name_index,[sys.generators.thermal[i].tech.activepower for i in 1:length(name_index)]))
    initialstatusdict = :initialstatusdict in keys(args) ? args[:initialstatusdict] : Dict(zip(name_index,ones(length(name_index))));
    initialondurationdict = :initialondurationdict in keys(args) ? args[:initialondurationdict] : Dict(zip(name_index,ones(length(name_index))*100));
    initialoffdurationdict = :initialoffdurationdict in keys(args) ? args[:initialoffdurationdict] : Dict(zip(name_index,zeros(length(name_index))));

    simulation_results = Dict();

            # run a PCM
    for (step, step_ts) in sort(simulation.timeseries)
        # assign TS to ps_dict
        ps_dict = Psys.assign_ts_data(ps_dict,step_ts); 

        # build sys
        sys = Psys.PowerSystem(ps_dict); 

        # make UC
        tmp_model = PS.PowerOperationModel(simulation.model.psmodel, 
            simulation.model.generation, 
            simulation.model.demand, 
            simulation.model.storage, 
            simulation.model.branches,
            simulation.model.transmission,
            simulation.model.services,
            sys,
            Model(), false, PTDF)


        # build model
        println( "Building model for $step ...")
        buildmodel!(sys, tmp_model; PTDF = PTDF,
            initialpower = initialpowerdict,
            initialstatus = initialstatusdict, 
            initialonduration = initialondurationdict, 
            initialoffduration = initialoffdurationdict)

        # solve model
        println("Solving model for $step ...")
        optimize!(tmp_model.model,with_optimizer(solver))

        status = tmp_model.model.moi_backend.model.optimizer.termination_status

        if status == JuMP.MOI.Success
            println( "Problem solved successfully...")
        else
            @warn "Problem solve unsuccessful, solver returned with status: $status"
        end

        # TODO: Subset model results when a lookahead is provided

        # extract results
        res = PS.get_model_result(tmp_model)

        simulation_results[step] = copy(res)

        # update initial...
        initialpowerdict = PS.get_previous_value(res[:p_th])
        initialstatusdict = PS.get_previous_value(res[:on_th])
        initialondurationdict = PS.commitment_duration(res,initialondurationdict,:start_th)
        initialoffdurationdict = PS.commitment_duration(res,initialoffdurationdict,:stop_th)

    end

    return simulation_results

end;




#example of simulation routine
# TODO: put this in the run_simulations function above
#=
function run_PCM(sys, ps_dict,steps,op_model)
    # Precalculate PTDF and initialize generator statuses
    PTDF,  A = PowerSystems.buildptdf(sys.branches, sys.buses) 

    name_index = [gen.name for gen in sys.generators.thermal];

    initialpowerdict = Dict(zip(name_index,[sys.generators.thermal[i].tech.activepower for i in 1:length(name_index)]))
    initialstatusdict = Dict(zip(name_index,ones(length(name_index))));
    initialondurationdict = Dict(zip(name_index,ones(length(name_index))*100));
    initialoffdurationdict = Dict(zip(name_index,zeros(length(name_index))));

    simulation_results = Dict();

            # run a PCM
    for (step, step_ts) in sort(steps)
        # assign TS to ps_dict
        ps_dict = Psys.assign_ts_data(ps_dict,step_ts); 

        # build sys
        # TODO: this can be squashed with latest Psys PR
        Buses, Generators, Storage, Branches, Loads, LoadZones ,Shunts  = Psys.ps_dict2ps_struct(ps_dict); 
        sys = Psys.PowerSystem(Buses, Generators,Loads,Branches,Storage,ps_dict["baseMVA"]); 

        # make UC
        UC = PS.PowerOperationModel(op_model.psmodel, 
            op_model.generation, 
            op_model.demand, 
            op_model.storage, 
            op_model.branches,
            op_model.transmission,
            op_model.services,
            sys,
            Model(), false, PTDF)


        # build model
        println( "Building model for $step ...")
        buildmodel!(sys, UC; PTDF = PTDF,
            initialpower = initialpowerdict,
            initialstatus = initialstatusdict, 
            initialonduration = initialondurationdict, 
            initialoffduration = initialoffdurationdict)

        # solve model
        println("Solving model for $step ...")
        optimize!(UC.model,with_optimizer(solver))

        status = UC.model.moi_backend.model.optimizer.termination_status

        if status == JuMP.MOI.Success
            println( "Problem solved successfully...")
        else
            @warn "Problem solve unsuccessful, solver returned with status: $status"
        end

        # extract results
        res = PS.get_model_result(UC)

        simulation_results[step] = copy(res)

        # update initial...
        initialpowerdict = PS.get_previous_value(res[:p_th])
        initialstatusdict = PS.get_previous_value(res[:on_th])
        initialondurationdict = PS.commitment_duration(res,initialondurationdict,:start_th)
        initialoffdurationdict = PS.commitment_duration(res,initialoffdurationdict,:stop_th)

    end
    return simulation_results
end;

=#
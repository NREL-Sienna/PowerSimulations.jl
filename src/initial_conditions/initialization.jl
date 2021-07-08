const RELAXED_FORMULATION_MAPPING = Dict(
    :ThermalStandard => DeviceModel(PSY.ThermalStandard, ThermalBasicUnitCommitment),
    :ThermalMultiStart =>
        DeviceModel(PSY.ThermalMultiStart, ThermalBasicUnitCommitment), # Compact vs Standard representation
    :HydroDispatch => DeviceModel(PSY.HydroDispatch, HydroDispatchRunOfRiver),
    :HydroEnergyReservoir =>
        DeviceModel(PSY.HydroEnergyReservoir, HydroDispatchRunOfRiver),
    :HydroPumpedStorage =>
        DeviceModel(PSY.HydroPumpedStorage, HydroDispatchPumpedStorage),
    :RenewableFix => DeviceModel(PSY.RenewableFix, FixedOutput),
    :RenewableDispatch => DeviceModel(PSY.RenewableDispatch, FixedOutput),
    :GenericBattery => DeviceModel(PSY.GenericBattery, BookKeeping),
    :BatteryEMS => DeviceModel(PSY.BatteryEMS, BookKeeping),
    :TapTransformer => DeviceModel(PSY.TapTransformer, StaticBranch),
    :Transformer2W => DeviceModel(PSY.Transformer2W, StaticBranch),
    :MonitoredLine => DeviceModel(PSY.MonitoredLine, StaticBranchUnbounded),
    :Line => DeviceModel(PSY.Line, StaticBranch),
    :HVDCLine => DeviceModel(PSY.HVDCLine, HVDCDispatch),
    :PowerLoad => DeviceModel(PSY.PowerLoad, StaticPowerLoad),
    :InterruptibleLoad => DeviceModel(PSY.InterruptibleLoad, StaticPowerLoad),
)

function _build_initialization_template(model::DecisionModel)
    ic_template = ProblemTemplate(problem.template.transmission)
    for (device, _) in problem.template.devices
        model = RELAXED_FORMULATION_MAPPING[device]
        set_device_model!(ic_template, model)
    end
    for (device, _) in problem.template.branches
        model = RELAXED_FORMULATION_MAPPING[device]
        set_device_model!(ic_template, model)
    end
    for (device, model) in problem.template.services
        set_service_model!(ic_template, model)
    end
    return ic_template
end

function _build_initialization_problem(
    model::DecisionModel{M},
    sim::Simulation,
) where {M <: DecisionProblem}
    settings = deepcopy(get_settings(model))
    set_horizon!(settings, 1)
    template = _build_initialization_template(model)
    ic_model = DecisionModel{M}(template, problem.sys, settings)
    build!(ic_model; output_dir = get_internal(model).output_dir, serialize = false)
    return ic_model
end

function _perform_initialization_step!(
    ic_op_model::DecisionModel,
    model::DecisionModel,
    sim::Simulation,
)
    ini_cond_chronology = get_sequence(sim).ini_cond_chronology
    optimization_containter = get_optimization_container(model)
    for (ini_cond_key, initial_conditions) in
        iterate_initial_conditions(optimization_containter)
        # TODO: Replace this convoluted way to get information with access to data store
        simulation_cache = sim.internal.simulation_cache
        for ic in initial_conditions
            name = get_device_name(ic)
            var_value = get_problem_variable(
                RecedingHorizon(),
                (ic_model => problem),
                name,
                ic.update_ref,
            )
            # We pass the simulation cache instead of the whole simulation to avoid definition dependencies.
            # All the inputs to calculate_ic_quantity are defined before the simulation object
            quantity = calculate_ic_quantity(
                ini_cond_key,
                ic,
                var_value,
                simulation_cache,
                get_resolution(model),
            )
            previous_value = get_condition(ic)
            PJ.set_value(ic.value, quantity)
            IS.@record :simulation InitialConditionUpdateEvent(
                get_current_time(sim),
                ini_cond_key,
                ic,
                quantity,
                previous_value,
                get_simulation_number(model),
            )
        end
    end
    return
end

function _create_initialization_problem(sim::Simulation)
    ic_model = _build_initialization_problem(first(get_problems(sim)), sim)
    solve!(ic_model)
    return ic_model
end

function _initialization_problems!(sim::Simulation)
    # NOTE: Here we assume the solution to the 1st period in the simulation provides a good initial conditions
    # for initializing the simulation, but is not always guaranteed to provide a feasible initial conditions.
    # Currently the formulations used in the initialization problem are pre-defined, customization option
    # is be added in future release.
    ic_model = _create_initialization_problem(sim)
    for (problem_number, (problem_name, problem)) in enumerate(get_problems(sim))
        _perform_initialization_step!(ic_model, model, sim)
    end
end

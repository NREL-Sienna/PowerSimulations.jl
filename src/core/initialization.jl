const RELAXED_FORMULATION_MAPPING = Dict(
    :ThermalStandard => DeviceModel(PSY.ThermalStandard, ThermalBasicUnitCommitment),
    :ThermalMultiStart => DeviceModel(PSY.ThermalMultiStart, ThermalBasicUnitCommitment), # Compact vs Standard representation
    :HydroDispatch =>  DeviceModel(PSY.HydroDispatch, HydroDispatchRunOfRiver),
    :HydroEnergyReservoir => DeviceModel(PSY.HydroEnergyReservoir, HydroDispatchRunOfRiver),
    :HydroPumpedStorage =>  DeviceModel(PSY.HydroPumpedStorage, HydroDispatchPumpedStorage),
    :RenewableFix => DeviceModel(PSY.RenewableFix, FixedOutput),
    :RenewableDispatch => DeviceModel(PSY.RenewableDispatch, RenewableFullDispatch),
    :GenericBattery => DeviceModel(PSY.GenericBattery, RenewableFullDispatch),
    :BatteryEMS => DeviceModel(PSY.BatteryEMS, RenewableFullDispatch),

    :TapTransformer => DeviceModel(PSY.TapTransformer, StaticBranch),
    :Transformer2W => DeviceModel(PSY.Transformer2W, StaticBranch),
    :MonitoredLine => DeviceModel(PSY.MonitoredLine, StaticBranchUnbounded),
    :Line => DeviceModel(PSY.Line, StaticBranch),
    :HVDCLine => DeviceModel(PSY.HVDCLine, HVDCDispatch),

    :PowerLoad => DeviceModel(PSY.PowerLoad, StaticPowerLoad),
    :InterruptibleLoad => DeviceModel(PSY.InterruptibleLoad, InterruptiblePowerLoad),
    :VariableReserve => ServiceModel(PSY.VariableReserve{PSY.ReserveUp}, RangeReserve),
    :ReserveDemandCurve => ServiceModel(PSY.ReserveDemandCurve{PSY.ReserveUp}, StepwiseCostReserve),
)

function _build_initialization_template(problem::OperationsProblem)
    ic_template = OperationsProblemTemplate(problem.template.transmission)
    for (device, model) in problem.template.devices
        model = RELAXED_FORMULATION_MAPPING[device]
        set_device_model!(ic_template, model)
    end
    for (device, model) in problem.template.branches
        model = RELAXED_FORMULATION_MAPPING[device]
        set_device_model!(ic_template, model)
    end
    for (device, model) in problem.template.services
        model = RELAXED_FORMULATION_MAPPING[device]
        set_service_model!(ic_template, model)
    end
    return ic_template
end

function _build_initialization_problem(problem::OperationsProblem{M}, sim) where {M <: AbstractOperationsProblem}
    settings = deepcopy(get_settings(problem))
    set_horizon!(settings, 1)
    template = _build_initialization_template(problem)
    ic_op_problem = OperationsProblem{M}(
        template, 
        problem.sys, 
        settings
    )
    build!(ic_op_problem, output_dir = get_internal(problem).output_dir)
    return ic_op_problem
end

function _perform_initialization_step!(ic_op_problem, problem, sim)

    ini_cond_chronology = get_sequence(sim).ini_cond_chronology
    optimization_containter = get_optimization_container(problem)
    for (ini_cond_key, initial_conditions) in iterate_initial_conditions(optimization_containter)
        # TODO: Replace this convoluted way to get information with access to data store
        simulation_cache = sim.internal.simulation_cache
        for ic in initial_conditions
            name = get_device_name(ic)
            var_value = get_problem_variable(
                RecedingHorizon(),
                (ic_op_problem => problem),
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
                get_resolution(problem),
            )
            previous_value = get_condition(ic)
            PJ.set_value(ic.value, quantity)
            IS.@record :simulation InitialConditionUpdateEvent(
                get_current_time(sim),
                ini_cond_key,
                ic,
                quantity,
                previous_value,
                get_simulation_number(problem),
            )
        end
    end
    return
end

function _create_initialization_problem(sim)
    for (problem_number, (problem_name, problem)) in enumerate(get_problems(sim))
        if problem_number <= 1
            ic_op_problem = _build_initialization_problem(problem, sim)
            solve!(ic_op_problem)
            return ic_op_problem
        end
    end

end

function _initialization_problems!(sim)
    ic_op_problem = _create_initialization_problem(sim)
    for (problem_number, (problem_name, problem)) in enumerate(get_problems(sim))
        _perform_initialization_step!(ic_op_problem, problem, sim)
    end
end

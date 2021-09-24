function get_initialization_template(model::OperationModel)
    ic_template = ProblemTemplate(get_network_model(model.template))
    for (_, device_model) in model.template.devices
        base_model = get_initialization_device_model(device_model)
        base_model.use_slacks = device_model.use_slacks
        base_model.duals = device_model.duals
        base_model.time_series_names = device_model.time_series_names
        base_model.attributes = device_model.attributes
        set_device_model!(ic_template, base_model)
    end
    for (_, device_model) in model.template.branches
        base_model = get_initialization_device_model(device_model)
        base_model.use_slacks = device_model.use_slacks
        base_model.duals = device_model.duals
        base_model.time_series_names = device_model.time_series_names
        base_model.attributes = device_model.attributes
        set_device_model!(ic_template, base_model)
    end
    ic_template.services = model.template.services
    return ic_template
end

function build_initialization_problem!(model::T) where {T <: OperationModel}
    model.internal.ic_model_container = deepcopy(get_optimization_container(model))
    ic_settings = model.internal.ic_model_container.settings
    # TODO: add interface to allow user to change the horizon
    model.internal.ic_model_container.JuMPmodel = _make_jump_model(ic_settings)
    template = get_initialization_template(model)
    init_optimization_container!(
        model.internal.ic_model_container,
        get_network_formulation(get_template(model)),
        get_system(model),
    )
    build_impl!(model.internal.ic_model_container, template, get_system(model))
    return
end

#=
function perform_initialization_step!(
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
            name = get_component_name(ic)
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
    ic_model = build_initialization_problem(first(get_problems(sim)), sim)
    solve!(ic_model)
    return ic_model
end

function _initialization_problems!(sim::Simulation)
    # NOTE: Here we assume the solution to the 1st period in the simulation provides a good initial conditions
    # for initializing the simulation, but is not always guaranteed to provide a feasible initial conditions.
    # Currently the formulations used in the initialization problem are pre-defined, customization option
    # is be added in future release.
    ic_model = create_initialization_problem(sim)
    for (problem_number, (problem_name, problem)) in enumerate(get_problems(sim))
        perform_initialization_step!(ic_model, model, sim)
    end
end
=#

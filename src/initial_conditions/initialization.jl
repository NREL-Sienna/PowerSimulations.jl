function get_initial_conditions_template(model::OperationModel)
    # This is done to avoid passing the duals but also not re-allocating the PTDF when it
    # exists
    network_model = NetworkModel(
        get_network_formulation(model.template);
        use_slacks = get_use_slacks(get_network_model(model.template)),
        PTDF_matrix = get_PTDF_matrix(get_network_model(model.template)),
        reduce_radial_branches = get_reduce_radial_branches(
            get_network_model(model.template),
        ),
    )
    network_model.radial_network_reduction =
        get_radial_network_reduction(get_network_model(model.template))
    network_model.subnetworks = get_subnetworks(get_network_model(model.template))
    bus_area_map = get_bus_area_map(get_network_model(model.template))
    if !isempty(bus_area_map)
        network_model.bus_area_map = get_bus_area_map(get_network_model(model.template))
    end

    ic_template = ProblemTemplate(network_model)
    for device_model in values(model.template.devices)
        base_model = get_initial_conditions_device_model(model, device_model)
        base_model.use_slacks = device_model.use_slacks
        base_model.time_series_names = device_model.time_series_names
        base_model.attributes = device_model.attributes
        set_device_model!(ic_template, base_model)
    end
    for device_model in values(model.template.branches)
        base_model = get_initial_conditions_device_model(model, device_model)
        base_model.use_slacks = device_model.use_slacks
        base_model.time_series_names = device_model.time_series_names
        base_model.attributes = device_model.attributes
        set_device_model!(ic_template, base_model)
    end

    for service_model in values(model.template.services)
        base_model = get_initial_conditions_service_model(model, service_model)
        base_model.use_slacks = service_model.use_slacks
        base_model.time_series_names = service_model.time_series_names
        base_model.attributes = service_model.attributes
        set_service_model!(ic_template, base_model)
    end
    return ic_template
end

function _make_init_jump_model(ic_settings::Settings)
    optimizer = get_optimizer(ic_settings)
    JuMPmodel = JuMP.Model(optimizer)
    warm_start_enabled = get_warm_start(ic_settings)
    solver_supports_warm_start = _validate_warm_start_support(JuMPmodel, warm_start_enabled)
    set_warm_start!(ic_settings, solver_supports_warm_start)
    if get_optimizer_solve_log_print(ic_settings)
        JuMP.unset_silent(JuMPmodel)
        @debug "optimizer unset to silent" _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    else
        JuMP.set_silent(JuMPmodel)
        @debug "optimizer set to silent" _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    end
    return JuMPmodel
end

function build_initial_conditions_model!(model::T) where {T <: OperationModel}
    model.internal.ic_model_container = deepcopy(get_optimization_container(model))
    ic_settings = deepcopy(model.internal.ic_model_container.settings)
    main_problem_horizon = get_horizon(ic_settings)
    # TODO: add an interface to allow user to configure initial_conditions problem
    model.internal.ic_model_container.JuMPmodel = _make_init_jump_model(ic_settings)
    template = get_initial_conditions_template(model)
    model.internal.ic_model_container.settings = ic_settings
    model.internal.ic_model_container.built_for_recurrent_solves = false
    set_horizon!(ic_settings, min(INITIALIZATION_PROBLEM_HORIZON, main_problem_horizon))
    init_optimization_container!(
        model.internal.ic_model_container,
        get_network_formulation(get_template(model)),
        get_system(model),
    )
    JuMP.set_string_names_on_creation(
        get_jump_model(model.internal.ic_model_container),
        false,
    )
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build Initialization $(get_name(model))" begin
        build_impl!(model.internal.ic_model_container, template, get_system(model))
    end
    return
end

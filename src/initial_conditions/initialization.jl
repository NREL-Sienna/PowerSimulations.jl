function get_initial_conditions_template(model::OperationModel)
    # This is done to avoid passing the duals but also not re-allocating the PTDF when it
    # exists
    network_model = NetworkModel(
        get_network_formulation(model.template);
        use_slacks = get_use_slacks(get_network_model(model.template)),
        PTDF = get_PTDF(get_network_model(model.template)),
    )

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
    ic_template.services = model.template.services
    return ic_template
end

function build_initial_conditions_model!(model::T) where {T <: OperationModel}
    model.internal.ic_model_container = deepcopy(get_optimization_container(model))
    ic_settings = deepcopy(model.internal.ic_model_container.settings)
    # TODO: add an interface to allow user to configure initial_conditions problem
    model.internal.ic_model_container.JuMPmodel = _make_jump_model(ic_settings)
    template = get_initial_conditions_template(model)
    model.internal.ic_model_container.settings = ic_settings
    set_horizon!(ic_settings, 3)
    init_optimization_container!(
        model.internal.ic_model_container,
        get_network_formulation(get_template(model)),
        get_system(model),
    )
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build Initialization $(get_name(model))" begin
        build_impl!(model.internal.ic_model_container, template, get_system(model))
    end
    return
end

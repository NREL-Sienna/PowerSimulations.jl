function get_initial_conditions_template(model::OperationModel)
    ic_template = ProblemTemplate(get_network_model(model.template))
    for device_model in values(model.template.devices)
        base_model = get_initial_conditions_device_model(device_model)
        base_model.use_slacks = device_model.use_slacks
        base_model.duals = device_model.duals
        base_model.time_series_names = device_model.time_series_names
        base_model.attributes = device_model.attributes
        set_device_model!(ic_template, base_model)
    end
    for device_model in values(model.template.branches)
        base_model = get_initial_conditions_device_model(device_model)
        base_model.use_slacks = device_model.use_slacks
        base_model.duals = device_model.duals
        base_model.time_series_names = device_model.time_series_names
        base_model.attributes = device_model.attributes
        set_device_model!(ic_template, base_model)
    end
    ic_template.services = model.template.services
    return ic_template
end

function build_initial_conditions_problem!(model::T) where {T <: OperationModel}
    model.internal.ic_model_container = deepcopy(get_optimization_container(model))
    ic_settings = model.internal.ic_model_container.settings
    # TODO: add an interface to allow user to configure initial_conditions problem
    model.internal.ic_model_container.JuMPmodel = _make_jump_model(ic_settings)
    template = get_initial_conditions_template(model)
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

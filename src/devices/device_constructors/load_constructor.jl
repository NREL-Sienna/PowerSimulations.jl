function construct_device!(op_model::OperationModel,
                           model::DeviceModel{L, D},
                           ::Type{S};
                           kwargs...) where {L<:PSY.ControllableLoad,
                                             D<:AbstractControllablePowerLoadFormulation,
                                             S<:PM.AbstractPowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables(op_model.canonical, devices)

    reactivepower_variables(op_model.canonical, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, L)
        activepower_constraints(op_model.canonical, forecasts, D, S)
    else
        activepower_constraints(op_model.canonical, devices, D, S)
    end

    reactivepower_constraints(op_model.canonical, devices, D, S)

    feedforward!(op_model.canonical, L, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, D, S)

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{L, D},
                           ::Type{S};
                           kwargs...) where {L<:PSY.ControllableLoad,
                                             D<:AbstractControllablePowerLoadFormulation,
                                             S<:PM.AbstractActivePowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables(op_model.canonical, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, L)
        activepower_constraints(op_model.canonical, forecasts, D, S)
    else
        activepower_constraints(op_model.canonical, devices, D, S)
    end

    feedforward!(op_model.canonical, L, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, D, S)

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{L, InterruptiblePowerLoad},
                           ::Type{S};
                           kwargs...) where {L<:PSY.ControllableLoad,
                                             S<:PM.AbstractPowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables(op_model.canonical, devices)

    reactivepower_variables(op_model.canonical, devices)

    commitment_variables(op_model.canonical, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, L)
        activepower_constraints(op_model.canonical, forecasts, model.formulation, S)
    else
        activepower_constraints(op_model.canonical, devices, model.formulation, S)
    end

    reactivepower_constraints(op_model.canonical, devices, model.formulation, S)

    feedforward!(op_model.canonical, L, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, model.formulation, S)

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{L, InterruptiblePowerLoad},
                           ::Type{S};
                           kwargs...) where {L<:PSY.ControllableLoad,
                                             S<:PM.AbstractActivePowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables(op_model.canonical, devices)

    commitment_variables(op_model.canonical, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, L)
        activepower_constraints(op_model.canonical, forecasts, model.formulation, S)
    else
        activepower_constraints(op_model.canonical, devices, model.formulation, S)
    end

    feedforward!(op_model.canonical, L, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, model.formulation, S)

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{L, StaticPowerLoad},
                           ::Type{S};
                           kwargs...) where {L<:PSY.ElectricLoad,
                                             S<:PM.AbstractPowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    if forecast
        forecasts = _retrieve_forecasts(sys, L)
        nodal_expression(op_model.canonical, forecasts, S)
    else
        nodal_expression(op_model.canonical, devices, S)
    end

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{L, D},
                           ::Type{S};
                           kwargs...) where {L<:PSY.StaticLoad,
                                             D<:AbstractControllablePowerLoadFormulation,
                                             S<:PM.AbstractPowerModel}

    if D != StaticPowerLoad
        @warn("The Formulation $(D) only applies to FormulationControllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad")
    end

    construct_device!(op_model,
                      DeviceModel(L, StaticPowerLoad),
                      S;
                      kwargs...)

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{R, D},
                           ::Type{S};
                           kwargs...) where {R<:PSY.RenewableGen,
                                             D<:AbstractRenewableDispatchFormulation,
                                             S<:PM.AbstractPowerModel}


    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    #Variables
    activepower_variables(op_model.canonical, devices);

    reactivepower_variables(op_model.canonical, devices);

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, R)
        activepower_constraints(op_model.canonical, forecasts, D, S)
    else
        activepower_constraints(op_model.canonical, devices, D, S)
    end

    reactivepower_constraints(op_model.canonical, devices, D, S)

    feedforward!(op_model.canonical, R, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, D, S)

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{R, D},
                           ::Type{S};
                           kwargs...) where {R<:PSY.RenewableGen,
                                             D<:AbstractRenewableDispatchFormulation,
                                             S<:PM.AbstractActivePowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    #Variables
    activepower_variables(op_model.canonical, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, R)
        activepower_constraints(op_model.canonical, forecasts, D, S)
    else
        activepower_constraints(op_model.canonical, devices, D, S)
    end

    feedforward!(op_model.canonical, R, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, D, S)

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{R, RenewableFixed},
                           system_formulation::Type{S};
                           kwargs...) where {R<:PSY.RenewableGen,
                                             S<:PM.AbstractPowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    if forecast
        forecasts = _retrieve_forecasts(sys, R)
        nodal_expression(op_model.canonical, forecasts, system_formulation)
    else
        nodal_expression(op_model.canonical, devices, system_formulation)
    end

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{PSY.RenewableFix, D},
                           system_formulation::Type{S};
                           kwargs...) where {D<:AbstractRenewableDispatchFormulation,
                                             S<:PM.AbstractPowerModel}

    @warn("The Formulation $(D) only applies to FormulationControllable Renewable Resources, \n Consider Changing the Device Formulation to RenewableFixed")

    construct_device!(op_model,
                      DeviceModel(PSY.RenewableFix,RenewableFixed),
                      system_formulation;
                      kwargs...)

    return

end


function construct_device!(op_model::OperationModel,
                           model::DeviceModel{PSY.RenewableFix, RenewableFixed},
                           system_formulation::Type{S};
                           kwargs...) where {S<:PM.AbstractPowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(PSY.RenewableFix, sys)

    if validate_available_devices(devices, PSY.RenewableFix)
        return
    end

    if forecast
        forecasts = _retrieve_forecasts(sys, PSY.RenewableFix)
        nodal_expression(op_model.canonical, forecasts, system_formulation)
    else
        nodal_expression(op_model.canonical, devices, system_formulation)
    end

    return

end

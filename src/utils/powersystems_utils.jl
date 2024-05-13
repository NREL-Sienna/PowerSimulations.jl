function get_available_components(
    model::DeviceModel{T, <:AbstractDeviceFormulation},
    sys::PSY.System,
) where {T <: PSY.Component}
    subsystem = get_subsystem(model)
    filter_function = get_attribute(model, "filter_function")
    if filter_function === nothing
        return PSY.get_components(
            PSY.get_available,
            T,
            sys;
            subsystem_name = subsystem,
        )
    else
        return PSY.get_components(
            x -> PSY.get_available(x) && filter_function(x),
            T,
            sys;
            subsystem_name = subsystem,
        )
    end
end

function get_available_components(
    model::ServiceModel{T, <:AbstractServiceFormulation},
    sys::PSY.System,
) where {T <: PSY.Component}
    subsystem = get_subsystem(model)
    filter_function = get_attribute(model, "filter_function")
    if filter_function === nothing
        return PSY.get_components(
            PSY.get_available,
            T,
            sys;
            subsystem_name = subsystem,
        )
    else
        return PSY.get_components(
            x -> PSY.get_available(x) && filter_function(x),
            T,
            sys;
            subsystem_name = subsystem,
        )
    end
end

function get_available_components(
    model::NetworkModel,
    ::Type{PSY.ACBus},
    sys::PSY.System,
)
    subsystem = get_subsystem(model)
    return PSY.get_components(
        x -> PSY.get_bustype(x) != PSY.ACBusTypes.ISOLATED,
        PSY.ACBus,
        sys;
        subsystem_name = subsystem,
    )
end

function get_available_components(
    model::NetworkModel,
    ::Type{T},
    sys::PSY.System,
) where {T <: PSY.Component}
    subsystem = get_subsystem(model)
    return PSY.get_components(
        T,
        sys;
        subsystem_name = subsystem,
    )
end

function get_available_components(
    ::Type{PSY.RegulationDevice{T}},
    sys::PSY.System,
) where {T <: PSY.Component}
    return PSY.get_components(
        x -> (PSY.get_available(x) && PSY.has_service(x, PSY.AGC)),
        PSY.RegulationDevice{T},
        sys,
    )
end

make_system_filename(sys::PSY.System) = make_system_filename(IS.get_uuid(sys))
make_system_filename(sys_uuid::Union{Base.UUID, AbstractString}) = "system-$(sys_uuid).json"

function check_hvdc_line_limits_consistency(
    d::Union{PSY.TwoTerminalHVDCLine, PSY.TModelHVDCLine},
)
    from_min = PSY.get_active_power_limits_from(d).min
    to_min = PSY.get_active_power_limits_to(d).min
    from_max = PSY.get_active_power_limits_from(d).max
    to_max = PSY.get_active_power_limits_to(d).max

    if from_max < to_min
        throw(
            IS.ConflictingInputsError(
                "From Max $(from_max) can't be a smaller value than To Min $(to_min)",
            ),
        )
    elseif to_max < from_min
        throw(
            IS.ConflictingInputsError(
                "To Max $(to_max) can't be a smaller value than From Min $(from_min)",
            ),
        )
    end
    return
end

function check_hvdc_line_limits_unidirectional(d::PSY.TwoTerminalHVDCLine)
    from_min = PSY.get_active_power_limits_from(d).min
    to_min = PSY.get_active_power_limits_to(d).min
    from_max = PSY.get_active_power_limits_from(d).max
    to_max = PSY.get_active_power_limits_to(d).max

    if from_min < 0 || to_min < 0 || from_max < 0 || to_max < 0
        throw(
            IS.ConflictingInputsError(
                "Changing flow direction on HVDC Line $(PSY.get_name(d)) is not compatible with non-linear network formulations. \
                Bi-directional models with losses are only compatible with linear network models like DCPPowerModel.",
            ),
        )
    end
    return
end

##################################################
########### Cost Function Utilities ##############
##################################################

"""
Obtain proportional (marginal or slope) cost data in system base per unit
depending on the specified power units
"""
function get_proportional_cost_per_system_unit(
    cost_term::Float64,
    ::Val{0}, # SystemBase Unit
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term
end

function get_proportional_cost_per_system_unit(
    cost_term::Float64,
    ::Val{1}, # DeviceBase Unit
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * (system_base_power / device_base_power)
end

function get_proportional_cost_per_system_unit(
    cost_term::Float64,
    ::Val{2}, # Natural Units
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * system_base_power
end

"""
Obtain quadratic cost data in system base per unit
depending on the specified power units
"""
function get_quadratic_cost_per_system_unit(
    cost_term::Float64,
    ::Val{0}, # SystemBase Unit
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term
end

function get_quadratic_cost_per_system_unit(
    cost_term::Float64,
    ::Val{1}, # DeviceBase Unit
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * (system_base_power / device_base_power)^2
end

function get_quadratic_cost_per_system_unit(
    cost_term::Float64,
    ::Val{2}, # Natural Units
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * system_base_power^2
end

##################################################
############### Auxiliary Methods ################
##################################################

# These conversions are not properly done for the new models
function convert_to_compact_variable_cost(
    var_cost::PSY.PiecewiseLinearData,
    p_min::Float64,
    no_load_cost::Float64,
)
    points = PSY.get_points(var_cost)
    new_points = [(pp - p_min, c - no_load_cost) for (pp, c) in points]
    return PSY.PiecewiseLinearData(new_points)
end

# These conversions are not properly done for the new models
function convert_to_compact_variable_cost(
    var_cost::PSY.PiecewiseStepData,
    p_min::Float64,
    no_load_cost::Float64,
)
    x = PSY.get_x_coords(var_cost)
    y = vcat(PSY.get_y_coords(var_cost), PSY.get_y_coords(var_cost)[end])
    points = [(x[i], y[i]) for i in length(x)]
    new_points = [(x = pp - p_min, y = c - no_load_cost) for (pp, c) in points]
    return PSY.PiecewiseLinearData(new_points)
end

# TODO: This method needs to be corrected to account for actual StepData. The TestData is point wise
function convert_to_compact_variable_cost(var_cost::PSY.PiecewiseStepData)
    p_min, no_load_cost = (PSY.get_x_coords(var_cost)[1], PSY.get_y_coords(var_cost)[1])
    return convert_to_compact_variable_cost(var_cost, p_min, no_load_cost)
end

function convert_to_compact_variable_cost(var_cost::PSY.PiecewiseLinearData)
    p_min, no_load_cost = first(PSY.get_points(var_cost))
    return convert_to_compact_variable_cost(var_cost, p_min, no_load_cost)
end

function _validate_compact_pwl_data(
    min::Float64,
    max::Float64,
    cost_data::PSY.PiecewiseStepData,
    base_power::Float64,
)
    data = PSY.get_x_coords(cost_data)
    if isapprox(max - min, last(data) / base_power) && iszero(first(data))
        return COMPACT_PWL_STATUS.VALID
    else
        return COMPACT_PWL_STATUS.INVALID
    end
end

function validate_compact_pwl_data(
    d::PSY.ThermalGen,
    data::PSY.PiecewiseStepData,
    base_power::Float64,
)
    min = PSY.get_active_power_limits(d).min
    max = PSY.get_active_power_limits(d).max
    return _validate_compact_pwl_data(min, max, data, base_power)
end

function validate_compact_pwl_data(
    d::PSY.Component,
    ::PSY.PiecewiseLinearData,
    ::Float64,
)
    @warn "Validation of compact pwl data is not implemented for $(typeof(d))."
    return COMPACT_PWL_STATUS.UNDETERMINED
end

get_breakpoint_upper_bounds = PSY.get_x_lengths

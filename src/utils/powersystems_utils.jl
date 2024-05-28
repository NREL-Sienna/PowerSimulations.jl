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
    unit_system::PSY.UnitSystem,
    system_base_power::Float64,
    device_base_power::Float64,
)
    return _get_proportional_cost_per_system_unit(
        cost_term,
        Val{unit_system}(),
        system_base_power,
        device_base_power,
    )
end

function _get_proportional_cost_per_system_unit(
    cost_term::Float64,
    ::Val{PSY.UnitSystem.SYSTEM_BASE},
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term
end

function _get_proportional_cost_per_system_unit(
    cost_term::Float64,
    ::Val{PSY.UnitSystem.DEVICE_BASE},
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * (system_base_power / device_base_power)
end

function _get_proportional_cost_per_system_unit(
    cost_term::Float64,
    ::Val{PSY.UnitSystem.NATURAL_UNITS},
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
    unit_system::PSY.UnitSystem,
    system_base_power::Float64,
    device_base_power::Float64,
)
    return _get_quadratic_cost_per_system_unit(
        cost_term,
        Val{unit_system}(),
        system_base_power,
        device_base_power,
    )
end

function _get_quadratic_cost_per_system_unit(
    cost_term::Float64,
    ::Val{PSY.UnitSystem.SYSTEM_BASE}, # SystemBase Unit
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term
end

function _get_quadratic_cost_per_system_unit(
    cost_term::Float64,
    ::Val{PSY.UnitSystem.DEVICE_BASE}, # DeviceBase Unit
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * (system_base_power / device_base_power)^2
end

function _get_quadratic_cost_per_system_unit(
    cost_term::Float64,
    ::Val{PSY.UnitSystem.NATURAL_UNITS}, # Natural Units
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_term * system_base_power^2
end

"""
Obtain the normalized PiecewiseLinear cost data in system base per unit
depending on the specified power units.

Note that the costs (y-axis) are always in \$/h so
they do not require transformation
"""
function get_piecewise_pointcurve_per_system_unit(
    cost_component::PSY.PiecewiseLinearData,
    unit_system::PSY.UnitSystem,
    system_base_power::Float64,
    device_base_power::Float64,
)
    return _get_piecewise_pointcurve_per_system_unit(
        cost_component,
        Val{unit_system}(),
        system_base_power,
        device_base_power,
    )
end

function _get_piecewise_pointcurve_per_system_unit(
    cost_component::PSY.PiecewiseLinearData,
    ::Val{PSY.UnitSystem.SYSTEM_BASE},
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_component
end

function _get_piecewise_pointcurve_per_system_unit(
    cost_component::PSY.PiecewiseLinearData,
    ::Val{PSY.UnitSystem.DEVICE_BASE},
    system_base_power::Float64,
    device_base_power::Float64,
)
    points = cost_component.points
    points_normalized = Vector{NamedTuple{(:x, :y)}}(undef, length(points))
    for (ix, point) in enumerate(points)
        points_normalized[ix] =
            (x = point.x * (device_base_power / system_base_power), y = point.y)
    end
    return PSY.PiecewiseLinearData(points_normalized)
end

function _get_piecewise_pointcurve_per_system_unit(
    cost_component::PSY.PiecewiseLinearData,
    ::Val{PSY.UnitSystem.NATURAL_UNITS},
    system_base_power::Float64,
    device_base_power::Float64,
)
    points = cost_component.points
    points_normalized = Vector{NamedTuple{(:x, :y)}}(undef, length(points))
    for (ix, point) in enumerate(points)
        points_normalized[ix] = (x = point.x / system_base_power, y = point.y)
    end
    return PSY.PiecewiseLinearData(points_normalized)
end

"""
Obtain the normalized PiecewiseStep cost data in system base per unit
depending on the specified power units.

Note that the costs (y-axis) are in \$/MWh, \$/(sys pu h) or \$/(device pu h),
so they also require transformation.
"""
function get_piecewise_incrementalcurve_per_system_unit(
    cost_component::PSY.PiecewiseStepData,
    unit_system::PSY.UnitSystem,
    system_base_power::Float64,
    device_base_power::Float64,
)
    return _get_piecewise_incrementalcurve_per_system_unit(
        cost_component,
        Val{unit_system}(),
        system_base_power,
        device_base_power,
    )
end

function _get_piecewise_incrementalcurve_per_system_unit(
    cost_component::PSY.PiecewiseStepData,
    ::Val{PSY.UnitSystem.SYSTEM_BASE},
    system_base_power::Float64,
    device_base_power::Float64,
)
    return cost_component
end

function _get_piecewise_incrementalcurve_per_system_unit(
    cost_component::PSY.PiecewiseStepData,
    ::Val{PSY.UnitSystem.DEVICE_BASE},
    system_base_power::Float64,
    device_base_power::Float64,
)
    x_coords = PSY.get_x_coords(cost_component)
    y_coords = PSY.get_y_coords(cost_component)
    ratio = device_base_power / system_base_power
    x_coords_normalized = x_coords .* ratio
    y_coords_normalized = y_coords ./ ratio
    return PSY.PiecewiseStepData(x_coords_normalized, y_coords_normalized)
end

function _get_piecewise_incrementalcurve_per_system_unit(
    cost_component::PSY.PiecewiseStepData,
    ::Val{PSY.UnitSystem.NATURAL_UNITS},
    system_base_power::Float64,
    device_base_power::Float64,
)
    x_coords = PSY.get_x_coords(cost_component)
    y_coords = PSY.get_y_coords(cost_component)
    x_coords_normalized = x_coords ./ system_base_power
    y_coords_normalized = y_coords .* system_base_power
    return PSY.PiecewiseStepData(x_coords_normalized, y_coords_normalized)
end

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

make_system_filename(sys::PSY.System) = "system-$(IS.get_uuid(sys)).json"
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

function _validate_compact_pwl_data(
    min::Float64,
    max::Float64,
    data::PSY.PiecewiseLinearPointData,
    base_power::Float64,
)
    data = PSY.get_points(data)
    if isapprox(max - min, last(data).x / base_power) && iszero(first(data).x)
        return COMPACT_PWL_STATUS.VALID
    else
        return COMPACT_PWL_STATUS.INVALID
    end
end

function validate_compact_pwl_data(
    d::PSY.ThermalGen,
    data::PSY.PiecewiseLinearPointData,
    base_power::Float64,
)
    min = PSY.get_active_power_limits(d).min
    max = PSY.get_active_power_limits(d).max
    return _validate_compact_pwl_data(min, max, data, base_power)
end

function validate_compact_pwl_data(
    d::PSY.Component,
    ::PSY.PiecewiseLinearPointData,
    ::Float64,
)
    @warn "Validation of compact pwl data is not implemented for $(typeof(d))."
    return COMPACT_PWL_STATUS.UNDETERMINED
end

get_breakpoint_upper_bounds = PSY.get_x_lengths

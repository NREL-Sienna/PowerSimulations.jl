function get_available_components(::Type{T}, sys::PSY.System) where {T <: PSY.Component}
    return PSY.get_components(PSY.get_available, T, sys)
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

function check_hvdc_line_limits_consistency(d::PSY.HVDCLine)
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

function check_hvdc_line_limits_unidirectional(d::PSY.HVDCLine)
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

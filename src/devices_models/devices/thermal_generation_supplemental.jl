########################### Thermal Generation Models ######################################
struct SupplementalThermalBasicUnitCommitment <: AbstractThermalUnitCommitment end
struct SupplementalThermalStandardUnitCommitment <: AbstractThermalUnitCommitment end
struct SupplementalThermalDispatch <: AbstractThermalDispatchFormulation end
struct SupplementalThermalRampLimited <: AbstractThermalDispatchFormulation end
struct SupplementalThermalDispatchNoMin <: AbstractThermalDispatchFormulation end

########################### Offline Service Limit ######################################
const OFFLINE_ACTIVE_RANGE = "offline_activerange"
const OFFLINE_ACTIVE_RANGE_LB = "offline_activerange_lb"
const OFFLINE_ACTIVE_RANGE_UB = "offline_activerange_ub"

"""
Calls add_offline_device_services! to get references of offline active service variables (from SupplementalStaticReserve),
and calls offline_device_semicontinuousrange! to limit those variables to `limit*(1-ON)` .
"""
function offline_activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, <:AbstractThermalFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
) where {T <: PSY.ThermalGen}
    constraint_data = Vector{DeviceRange}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limits = PSY.get_activepowerlimits(d)
        name = PSY.get_name(d)
        range_data = DeviceRange(name, limits)
        add_offline_device_services!(range_data, d, model)
        constraint_data[ix] = range_data
    end

    offline_device_semicontinuousrange(
        psi_container,
        constraint_data,
        constraint_name(OFFLINE_ACTIVE_RANGE, T),
        variable_name(ON, T),
    )

    return
end

"""
Limits SupplementalStaticReserve offline active service variables: `Pmin*(1-ON) <= poff <= Pmax*(1-ON)` .
"""
function offline_device_semicontinuousrange!(
    psi_container::PSIContainer,
    range_data::Vector{DeviceRange},
    cons_name::Symbol,
    binvar_name::Symbol,
)

    time_steps = model_time_steps(psi_container)
    varbin = get_variable(psi_container, binvar_name)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")
    names = (d.name for d in range_data)
    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, names, time_steps)

    for data in range_data, t in time_steps
        expression_ub = JuMP.AffExpr()
        for val in data.additional_terms_ub
            JuMP.add_to_expression!(
                expression_ub,
                get_variable(psi_container, val)[data.name, t],
            )
        end
        expression_lb = JuMP.AffExpr()
        for val in data.additional_terms_lb
            JuMP.add_to_expression!(
                expression_lb,
                get_variable(psi_container, val)[data.name, t],
                -1.0,
            )
        end
        con_ub[data.name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_ub <= data.limits.max * (1 - varbin[data.name, t])
        )
        con_lb[data.name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            expression_lb >= data.limits.min * (1 - varbin[data.name, t])
        )
    end

end

"""Adds offline service variables references to additional_terms_ub"""
function include_offline_service!(
    constraint_data::DeviceRange,
    services,
    ::ServiceModel{SR, <:AbstractReservesFormulation},
) where {SR <: PSY.SupplementalStaticReserve{PSY.ReserveUp}}
    for (ix, service) in enumerate(services)
        push!(
            constraint_data.additional_terms_ub,
            constraint_name(PSY.get_name(service)*"_off", SR),
        )
    end
    return
end

"""Adds offline service variables references to additional_terms_lb"""
function include_offline_service!(
    constraint_data::DeviceRange,
    services,
    ::ServiceModel{SR, <:AbstractReservesFormulation},
) where {SR <: PSY.SupplementalStaticReserve{PSY.ReserveDown}}
    for (ix, service) in enumerate(services)
        push!(
            constraint_data.additional_terms_lb,
            constraint_name(PSY.get_name(service)*"_off", SR),
        )
    end
    return
end

"""
Calls include_offline_service! to include SupplementalStaticReserve 
offline service variables references in additional_terms_ub and additional_terms_lb.
"""
function add_offline_device_services!(
    constraint_data::RangeConstraintsData,
    device::D,
    model::DeviceModel
) where {D <: PSY.Device}
    for service_model in get_services(model)
        if PSY.has_service(device, service_model.service_type) && service_model.service_type == PSY.SupplementalStaticReserve
            services =
                (s for s in PSY.get_services(device) if isa(s, service_model.service_type))
            @assert !isempty(services)
            include_offline_service!(constraint_data, services, service_model)
        end
    end
    return
end

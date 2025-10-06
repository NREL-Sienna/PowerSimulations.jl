function add_parallel_ac_transmission!(
    sys::System,
    ac_transmission::PSY.Line,
    ::Type{T},
) where {T <: PSY.Line}
    ac_transmission_copy = Line(;
        name = PSY.get_name(ac_transmission) * "_copy",
        available = PSY.get_available(ac_transmission),
        active_power_flow = PSY.get_active_power_flow(ac_transmission),
        reactive_power_flow = PSY.get_reactive_power_flow(ac_transmission),
        arc = PSY.get_arc(ac_transmission),
        r = PSY.get_r(ac_transmission),
        x = PSY.get_x(ac_transmission),
        b = PSY.get_b(ac_transmission),
        rating = PSY.get_rating(ac_transmission),
        angle_limits = PSY.get_angle_limits(ac_transmission),
        rating_b = PSY.get_rating_b(ac_transmission),
        rating_c = PSY.get_rating_c(ac_transmission),
        g = PSY.get_g(ac_transmission),
        services = PSY.get_services(ac_transmission),
        ext = PSY.get_ext(ac_transmission))
    add_component!(sys, ac_transmission_copy)
end

function add_parallel_ac_transmission!(
    sys::System,
    ac_transmission::PSY.ACTransmission,
    ::Type{T},
    ::Type{MonitoredLine},
) where {T <: PSY.Line}
    ac_transmission_copy = MonitoredLine(;
        name = PSY.get_name(ac_transmission) * "_copy",
        available = PSY.get_available(ac_transmission),
        active_power_flow = PSY.get_active_power_flow(ac_transmission),
        reactive_power_flow = PSY.get_reactive_power_flow(ac_transmission),
        arc = PSY.get_arc(ac_transmission),
        r = PSY.get_r(ac_transmission),
        x = PSY.get_x(ac_transmission),
        b = PSY.get_b(ac_transmission),
        flow_limits = (
            from_to = PSY.get_rating(ac_transmission),
            to_from = PSY.get_rating(ac_transmission),
        ),
        rating = PSY.get_rating(ac_transmission),
        angle_limits = PSY.get_angle_limits(ac_transmission),
        rating_b = PSY.get_rating_b(ac_transmission),
        rating_c = PSY.get_rating_c(ac_transmission),
        g = PSY.get_g(ac_transmission),
        services = PSY.get_services(ac_transmission),
        ext = PSY.get_ext(ac_transmission))
    add_component!(sys, ac_transmission_copy)
end

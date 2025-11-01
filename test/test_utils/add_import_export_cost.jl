const _IECComponentType = Source
const _IEC_COMPONENT_NAME = "source"
const SEL_IEC = make_selector(_IECComponentType, _IEC_COMPONENT_NAME)

function make_5_bus_with_import_export(; add_single_time_series::Bool = false)
    sys = build_system(
        PSITestSystems,
        "c_sys5_uc";
        add_single_time_series = add_single_time_series,
    )

    source = _IECComponentType(;
        name = _IEC_COMPONENT_NAME,
        available = true,
        bus = get_component(ACBus, sys, "nodeC"),
        active_power = 0.0,
        reactive_power = 0.0,
        active_power_limits = (min = -2.0, max = 2.0),
        reactive_power_limits = (min = -2.0, max = 2.0),
        R_th = 0.01,
        X_th = 0.02,
        internal_voltage = 1.0,
        internal_angle = 0.0,
        base_power = 100.0,
    )

    import_curve = make_import_curve(
        [0.0, 100.0, 105.0, 120.0, 200.0],
        [5.0, 10.0, 20.0, 40.0],
    )

    export_curve = make_export_curve(
        [0.0, 100.0, 105.0, 120.0, 200.0],
        [12.0, 8.0, 4.0, 0.0],
    )

    ie_cost = ImportExportCost(;
        import_offer_curves = import_curve,
        export_offer_curves = export_curve,
        ancillary_service_offers = Vector{Service}(),
        energy_import_weekly_limit = 1e6,
        energy_export_weekly_limit = 1e6,
    )

    set_operation_cost!(source, ie_cost)
    add_component!(sys, source)
    @assert get_component(SEL_IEC, sys) == source
    return sys
end


function make_5_bus_with_import_export_ts(
    incr_breakpoints_vary::Bool,
    incr_slopes_vary::Bool,
    decr_breakpoints_vary::Bool,
    decr_slopes_vary::Bool;
    add_single_time_series::Bool = false)

    (incr_breakpoints_vary || incr_slopes_vary ||
        decr_breakpoints_vary || decr_slopes_vary) &&
        throw(IS.NotImplementedError(
            "Varying import/export offer curves with time series is not implemented yet."
        ))
    
    sys = make_5_bus_with_import_export(; add_single_time_series = add_single_time_series)
    source = get_component(SEL_IEC, sys)
    oc = get_operation_cost(source)::ImportExportCost
    ioc = get_import_offer_curves(oc)
    eoc = get_export_offer_curves(oc)
    import_fd = get_function_data(ioc)
    export_fd = get_function_data(eoc)
    @show import_fd
    @show export_fd

    # TODO finish this
end

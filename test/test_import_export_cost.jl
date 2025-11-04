# See also test_device_source_constructors.jl
@testset "ImportExportCost incremental+decremental Source, no time series versus constant time series" begin
    sys_no_ts = make_5_bus_with_import_export(; name = "sys_no_ts")
    sys_constant_ts =
        make_5_bus_with_ie_ts(false, false, false, false; name = "sys_constant_ts")
    test_generic_mbc_equivalence(sys_no_ts, sys_constant_ts;
        device_to_formulation = FormulationDict(Source => ImportExportSourceModel),
    )
end

@testset "ImportExportCost with time varying import slopes" begin
    import_scalar = 0.5  # ultimately multiplies ActivePowerOutVariable objective function coefficient
    export_scalar = 2.0  # ultimately multiplies ActivePowerInVariable objective function coefficient
    sys_constant = make_5_bus_with_ie_ts(false, false, false, false;
        import_scalar = import_scalar, export_scalar = export_scalar,
        name = "sys_constant")
    sys_varying_import_slopes = make_5_bus_with_ie_ts(false, true, false, false;
        import_scalar = import_scalar, export_scalar = export_scalar,
        name = "sys_varying_import_slopes")
    iec_obj_fun_test_wrapper(sys_constant, sys_varying_import_slopes)
end

@testset "ImportExportCost with time varying import breakpoints" begin
    import_scalar = 0.2  # NOTE this maxes out ActivePowerOutVariable
    export_scalar = 2.0
    sys_constant = make_5_bus_with_ie_ts(false, false, false, false;
        import_scalar = import_scalar, export_scalar = export_scalar,
        name = "sys_constant")
    sys_varying_import_breakpoints = make_5_bus_with_ie_ts(true, false, false, false;
        import_scalar = import_scalar, export_scalar = export_scalar,
        name = "sys_varying_import_breakpoints")
    iec_obj_fun_test_wrapper(sys_constant, sys_varying_import_breakpoints)
end

@testset "ImportExportCost with time varying export slopes" begin
    import_scalar = 0.5
    export_scalar = 2.0
    sys_constant = make_5_bus_with_ie_ts(false, false, false, false;
        import_scalar = import_scalar, export_scalar = export_scalar,
        name = "sys_constant")
    sys_varying_export_slopes = make_5_bus_with_ie_ts(false, false, false, true;
        import_scalar = import_scalar, export_scalar = export_scalar,
        name = "sys_varying_export_slopes")
    iec_obj_fun_test_wrapper(sys_constant, sys_varying_export_slopes)
end

@testset "ImportExportCost with time varying export breakpoints" begin
    import_scalar = 1.0
    export_scalar = 40.0  # NOTE this maxes out ActivePowerInVariable
    sys_constant = make_5_bus_with_ie_ts(false, false, false, false;
        import_scalar = import_scalar, export_scalar = export_scalar,
        name = "sys_constant")
    sys_varying_export_breakpoints = make_5_bus_with_ie_ts(false, false, true, false;
        import_scalar = import_scalar, export_scalar = export_scalar,
        name = "sys_varying_export_breakpoints")
    iec_obj_fun_test_wrapper(sys_constant, sys_varying_export_breakpoints)
end

@testset "ImportExportCost with time varying everything" begin
    import_scalar = 0.2
    export_scalar = 40.0  # NOTE this maxes out ActivePowerInVariable
    sys_constant = make_5_bus_with_ie_ts(false, false, false, false;
        import_scalar = import_scalar, export_scalar = export_scalar,
        name = "sys_constant")
    sys_varying_everything = make_5_bus_with_ie_ts(true, true, true, true;
        import_scalar = import_scalar, export_scalar = export_scalar,
        name = "sys_varying_everything")
    iec_obj_fun_test_wrapper(sys_constant, sys_varying_everything)
end

# See also test_device_source_constructors.jl
@testset "ImportExportCost incremental+decremental Source, no time series versus constant time series" begin
    sys_no_ts = make_5_bus_with_import_export()
    set_name!(sys_no_ts, "sys_no_ts")
    sys_constant_ts = make_5_bus_with_import_export_ts(false, false, false, false)
    set_name!(sys_constant_ts, "sys_constant_ts")
    test_generic_mbc_equivalence(sys_no_ts, sys_constant_ts;
        device_to_formulation = FormulationDict(Source => ImportExportSourceModel),
    )
end

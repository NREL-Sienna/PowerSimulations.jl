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
    sys_constant = make_5_bus_with_ie_ts(false, false, false, false)
    set_name!(sys_constant, "sys_constant")
    sys_varying_import_slopes = make_5_bus_with_ie_ts(false, true, false, false)

    for use_simulation in (false, true)
        for in_memory_store in (use_simulation ? (false, true) : (false,))
            decisions1, decisions2 = run_iec_obj_fun_test(
                sys_constant,
                sys_varying_import_slopes,
                IEC_COMPONENT_NAME,
                IECComponentType;
                simulation = use_simulation,
                in_memory_store = in_memory_store,
            )

            if !all(isapprox.(decisions1, decisions2))
                @show decisions1
                @show decisions2
            end
            @assert all(approx_geq_1.(decisions1))
        end
    end
end

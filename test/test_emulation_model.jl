@testset "Emulation Model Build" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc"; add_single_time_series = true)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re"; add_single_time_series = true)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_uc_re"; add_single_time_series = true)
end

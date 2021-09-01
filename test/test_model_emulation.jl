@testset "Emulation Model Build" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(
        PSITestSystems,
        "c_sys5_uc";
        add_single_time_series = true,
        force_build = true,
    )
    # c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re"; add_single_time_series = true)
    # c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_uc_re"; add_single_time_series = true)

    # The initial time kwarg can be removed when
    model = EmulationModel(
        template,
        c_sys5;
        optimizer = GLPK_optimizer,
        initial_time = DateTime("2024-01-01T00:00:00"),
    )
    @test build!(model; output_dir = mktempdir(cleanup = true)) == BuildStatus.BUILT
end

@testset "Show recorder events in EmulationModel" begin
    template = get_thermal_standard_uc_template()
    c_sys5_uc_re = PSB.build_system(
        PSITestSystems,
        "c_sys5_uc_re";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    model = EmulationModel(template, c_sys5_uc_re; optimizer = GLPK_optimizer)

    @test build!(model; executions = 10, output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    @test run!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    recorder_log = joinpath(PSI.get_recorder_dir(model), "execution.log")
    events = list_recorder_events(PSI.ParameterUpdateEvent, recorder_log)
    @test !isempty(events)
    events = list_recorder_events(PSI.InitialConditionUpdateEvent, recorder_log)
    @test !isempty(events)
    for wall_time in (true, false)
        show_recorder_events(
            devnull,
            PSI.InitialConditionUpdateEvent,
            recorder_log;
            wall_time = wall_time,
        )
    end
end

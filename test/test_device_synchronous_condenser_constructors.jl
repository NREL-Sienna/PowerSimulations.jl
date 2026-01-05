@testset "SynchronousCondenserBasicDispatch SynchronousCondenser With ACPPowerModel" begin
    sys = build_system(PSITestSystems, "c_sys5_uc"; add_single_time_series = true)

    syncon = SynchronousCondenser(;
        name = "syncon_test",
        available = true,
        bus = get_component(ACBus, sys, "nodeB"),
        reactive_power = 0.0,
        rating = 2.0,
        reactive_power_limits = (min = -2.0, max = 2.0),
        base_power = 100.0,
    )

    add_component!(sys, syncon)

    template = ProblemTemplate(ACPPowerModel)
    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, Line, StaticBranch)
    set_device_model!(template, SynchronousCondenser, SynchronousCondenserBasicDispatch)

    transform_single_time_series!(sys, Hour(24), Hour(24))
    model = DecisionModel(
        template,
        sys;
        name = "UC",
        optimizer = Ipopt.Optimizer,
        store_variable_names = true,
    )
    build!(model; output_dir = mktempdir(; cleanup = true)) == PSI.ModelBuildStatus.BUILT
    solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    res = OptimizationProblemResults(model)
    q_syncon = read_variable(
        res,
        "ReactivePowerVariable__SynchronousCondenser";
        table_format = TableFormat.WIDE,
    )
    @test any(q_syncon[!, 2] != 0.0)
end

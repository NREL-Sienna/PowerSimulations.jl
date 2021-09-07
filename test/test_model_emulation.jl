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
    model = EmulationModel(template, c_sys5; optimizer = Cbc_optimizer)
    executions = 10
    @test build!(model; executions = executions, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    @test run!(model) == RunStatus.SUCCESSFUL
    results = ProblemResults(model)
    @test list_aux_variable_names(results) == []
    @test list_aux_variable_keys(results) == []
    @test list_variable_names(results) == ["ActivePowerVariable_ThermalStandard"]
    @test list_variable_keys(results) ==
          [PSI.VariableKey(ActivePowerVariable, ThermalStandard)]
    @test list_dual_names(results) == []
    @test list_dual_keys(results) == []
    @test list_parameter_names(results) == ["ActivePowerTimeSeriesParameter_PowerLoad"]
    @test list_parameter_keys(results) ==
          [PSI.ParameterKey(ActivePowerTimeSeriesParameter, PowerLoad)]

    @test read_variable(results, "ActivePowerVariable_ThermalStandard") isa DataFrame
    @test read_variable(results, ActivePowerVariable, ThermalStandard) isa DataFrame
    @test read_variable(results, PSI.VariableKey(ActivePowerVariable, ThermalStandard)) isa
          DataFrame

    @test read_parameter(results, "ActivePowerTimeSeriesParameter_PowerLoad") isa DataFrame
    @test read_parameter(results, ActivePowerTimeSeriesParameter, PowerLoad) isa DataFrame
    @test read_parameter(
        results,
        PSI.ParameterKey(ActivePowerTimeSeriesParameter, PowerLoad),
    ) isa DataFrame

    @test read_optimizer_stats(model) isa DataFrame
    @test read_optimizer_stats(model) == read_optimizer_stats(results)

    for i in 1:executions
        @test get_objective_value(results, i) isa Float64
    end
end

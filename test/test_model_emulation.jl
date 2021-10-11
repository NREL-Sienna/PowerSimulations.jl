@testset "Emulation Model Build" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(
        PSITestSystems,
        "c_sys5_uc";
        add_single_time_series = true,
        force_build = true,
    )

    model = EmulationModel(template, c_sys5; optimizer = GLPK_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    @test run!(model) == RunStatus.SUCCESSFUL

    template = get_thermal_standard_uc_template()
    c_sys5_uc_re = PSB.build_system(
        PSITestSystems,
        "c_sys5_uc_re";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    model = EmulationModel(template, c_sys5_uc_re; optimizer = GLPK_optimizer)

    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    @test run!(model) == RunStatus.SUCCESSFUL
    @test !isempty(collect(readdir(PSI.get_recorder_dir(model))))
end

@testset "Emulation Model initial_conditions test for ThermalGen" begin
    ######## Test with ThermalStandardUnitCommitment ########
    template = get_thermal_standard_uc_template()
    c_sys5_uc_re = PSB.build_system(
        PSITestSystems,
        "c_sys5_uc_re";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    model = EmulationModel(template, c_sys5_uc_re; optimizer = Cbc_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    check_duration_on_initial_conditions_values(model, ThermalStandard)
    check_duration_off_initial_conditions_values(model, ThermalStandard)
    @test run!(model) == RunStatus.SUCCESSFUL

    ######## Test with ThermalMultiStartUnitCommitment ########
    template = get_thermal_standard_uc_template()
    c_sys5_uc = PSB.build_system(
        PSITestSystems,
        "c_sys5_pglib";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, ThermalMultiStart, ThermalMultiStartUnitCommitment)
    model = EmulationModel(template, c_sys5_uc; optimizer = Cbc_optimizer)
    @test build!(model; executions = 1, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT

    check_duration_on_initial_conditions_values(model, ThermalStandard)
    check_duration_off_initial_conditions_values(model, ThermalStandard)
    check_duration_on_initial_conditions_values(model, ThermalMultiStart)
    check_duration_off_initial_conditions_values(model, ThermalMultiStart)
    @test run!(model) == RunStatus.SUCCESSFUL

    ######## Test with ThermalCompactUnitCommitment ########
    template = get_thermal_standard_uc_template()
    c_sys5_uc = PSB.build_system(
        PSITestSystems,
        "c_sys5_pglib";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, ThermalMultiStart, ThermalCompactUnitCommitment)
    model = EmulationModel(template, c_sys5_uc; optimizer = Cbc_optimizer)
    @test build!(model; executions = 1, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    check_duration_on_initial_conditions_values(model, ThermalStandard)
    check_duration_off_initial_conditions_values(model, ThermalStandard)
    check_duration_on_initial_conditions_values(model, ThermalMultiStart)
    check_duration_off_initial_conditions_values(model, ThermalMultiStart)
    @test run!(model) == RunStatus.SUCCESSFUL

    ######## Test with ThermalCompactDispatch ########
    template = get_thermal_standard_uc_template()
    c_sys5_uc = PSB.build_system(
        PSITestSystems,
        "c_sys5_pglib";
        add_single_time_series = true,
        force_build = true,
    )
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    set_device_model!(template, device_model)
    model = EmulationModel(template, c_sys5_uc; optimizer = Cbc_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
end

@testset "Emulation Model initial_conditions test for Storage" begin
    ######## Test with BookKeeping ########
    template = get_thermal_dispatch_template_network()
    c_sys5_bat = PSB.build_system(
        PSITestSystems,
        "c_sys5_bat";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, GenericBattery, BookKeeping)
    model = EmulationModel(template, c_sys5_bat; optimizer = Cbc_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    ic_data = PSI.get_initial_condition(
        PSI.get_optimization_container(model),
        InitialEnergyLevel(),
        GenericBattery,
    )
    for ic in ic_data
        name = PSY.get_name(ic.component)
        e_var = JuMP.value(PSI.get_value(ic))
        @test PSY.get_initial_energy(ic.component) == e_var
    end
    @test run!(model) == RunStatus.SUCCESSFUL

    ######## Test with BatteryAncillaryServices ########
    template = get_thermal_dispatch_template_network()
    c_sys5_bat = PSB.build_system(
        PSITestSystems,
        "c_sys5_bat";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, GenericBattery, BatteryAncillaryServices)
    model = EmulationModel(template, c_sys5_bat; optimizer = Cbc_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    ic_data = PSI.get_initial_condition(
        PSI.get_optimization_container(model),
        InitialEnergyLevel(),
        GenericBattery,
    )
    for ic in ic_data
        name = PSY.get_name(ic.component)
        e_var = JuMP.value(PSI.get_value(ic))
        @test PSY.get_initial_energy(ic.component) == e_var
    end
    @test run!(model) == RunStatus.SUCCESSFUL

    ######## Test with EnergyTarget ########
    template = get_thermal_dispatch_template_network()
    c_sys5_bat = PSB.build_system(
        PSITestSystems,
        "c_sys5_bat_ems";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, BatteryEMS, EnergyTarget)
    model = EmulationModel(template, c_sys5_bat; optimizer = Cbc_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    ic_data = PSI.get_initial_condition(
        PSI.get_optimization_container(model),
        InitialEnergyLevel(),
        BatteryEMS,
    )
    for ic in ic_data
        name = PSY.get_name(ic.component)
        e_var = JuMP.value(PSI.get_value(ic))
        @test PSY.get_initial_energy(ic.component) == e_var
    end
    @test run!(model) == RunStatus.SUCCESSFUL
end

@testset "Emulation Model initial_conditions test for Hydro" begin
    ######## Test with HydroDispatchRunOfRiver ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(
        PSITestSystems,
        "c_sys5_hyd";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, HydroDispatch, HydroDispatchRunOfRiver)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchRunOfRiver)
    model = EmulationModel(template, c_sys5_hyd; optimizer = Cbc_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test !PSI.has_initial_condition_value(
        initial_conditions_data,
        ActivePowerVariable(),
        HydroEnergyReservoir,
    )
    @test run!(model) == RunStatus.SUCCESSFUL

    ######## Test with HydroCommitmentRunOfRiver ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(
        PSITestSystems,
        "c_sys5_hyd";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, HydroDispatch, HydroCommitmentRunOfRiver)
    set_device_model!(template, HydroEnergyReservoir, HydroCommitmentRunOfRiver)
    model = EmulationModel(template, c_sys5_hyd; optimizer = Cbc_optimizer)

    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test PSI.has_initial_condition_value(
        initial_conditions_data,
        OnVariable(),
        HydroEnergyReservoir,
    )
    @test run!(model) == RunStatus.SUCCESSFUL

    ######## Test with HydroCommitmentRunOfRiver ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(
        PSITestSystems,
        "c_sys5_hyd";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirBudget)
    model = EmulationModel(template, c_sys5_hyd; optimizer = Cbc_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test !PSI.has_initial_condition_value(
        initial_conditions_data,
        ActivePowerVariable(),
        HydroEnergyReservoir,
    )
    @test run!(model) == RunStatus.SUCCESSFUL

    ######## Test with HydroCommitmentRunOfRiver ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(
        PSITestSystems,
        "c_sys5_hyd";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, HydroEnergyReservoir, HydroCommitmentReservoirBudget)
    model = EmulationModel(template, c_sys5_hyd; optimizer = Cbc_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test PSI.has_initial_condition_value(
        initial_conditions_data,
        OnVariable(),
        HydroEnergyReservoir,
    )
    @test run!(model) == RunStatus.SUCCESSFUL

    ######## Test with HydroCommitmentRunOfRiver ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(
        PSITestSystems,
        "c_sys5_hyd_ems";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirStorage)
    model = EmulationModel(template, c_sys5_hyd; optimizer = Cbc_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test !PSI.has_initial_condition_value(
        initial_conditions_data,
        ActivePowerVariable(),
        HydroEnergyReservoir,
    )
    ic_data = PSI.get_initial_condition(
        PSI.get_optimization_container(model),
        InitialEnergyLevel(),
        HydroEnergyReservoir,
    )
    for ic in ic_data
        name = PSY.get_name(ic.component)
        e_var = JuMP.value(PSI.get_value(ic))
        @test PSY.get_initial_storage(ic.component) == e_var
    end
    @test run!(model) == RunStatus.SUCCESSFUL

    ######## Test with HydroCommitmentRunOfRiver ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(
        PSITestSystems,
        "c_sys5_hyd_ems";
        add_single_time_series = true,
        force_build = true,
    )
    set_device_model!(template, HydroEnergyReservoir, HydroCommitmentReservoirStorage)
    model = EmulationModel(template, c_sys5_hyd; optimizer = Cbc_optimizer)
    @test build!(model; executions = 10, output_dir = mktempdir(cleanup = true)) ==
          BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test PSI.has_initial_condition_value(
        initial_conditions_data,
        OnVariable(),
        HydroEnergyReservoir,
    )
    ic_data = PSI.get_initial_condition(
        PSI.get_optimization_container(model),
        InitialEnergyLevel(),
        HydroEnergyReservoir,
    )
    for ic in ic_data
        name = PSY.get_name(ic.component)
        e_var = JuMP.value(PSI.get_value(ic))
        @test PSY.get_initial_storage(ic.component) == e_var
    end
    @test run!(model) == RunStatus.SUCCESSFUL
end

@testset "Emulation Model Results" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(
        PSITestSystems,
        "c_sys5_uc";
        add_single_time_series = true,
        force_build = true,
    )

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

@testset "Run EmulationModel with auto-build" begin
    for serialize in (true, false)
        template = get_thermal_dispatch_template_network()
        c_sys5 = PSB.build_system(
            PSITestSystems,
            "c_sys5_uc";
            add_single_time_series = true,
            force_build = true,
        )

        model = EmulationModel(template, c_sys5; optimizer = Cbc_optimizer)
        @test_throws ErrorException run!(model, executions = 10)
        @test run!(
            model,
            executions = 10,
            output_dir = mktempdir(cleanup = true),
            serialize = serialize,
        ) == RunStatus.SUCCESSFUL
    end
end

@testset "Test serialization/deserialization of EmulationModel results" begin
    path = mktempdir(cleanup = true)
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(
        PSITestSystems,
        "c_sys5_uc";
        add_single_time_series = true,
        force_build = true,
    )

    model = EmulationModel(template, c_sys5; optimizer = Cbc_optimizer)
    executions = 10
    @test build!(model; executions = executions, output_dir = path) == BuildStatus.BUILT
    @test run!(model, export_problem_results = true) == RunStatus.SUCCESSFUL
    results1 = ProblemResults(model)
    var1_a = read_variable(results1, ActivePowerVariable, ThermalStandard)
    # Ensure that we can deserialize strings into keys.
    var1_b = read_variable(results1, "ActivePowerVariable_ThermalStandard")
    @test var1_a == var1_b

    # Results were automatically serialized here.
    results2 = ProblemResults(joinpath(PSI.get_output_dir(model)))
    var2 = read_variable(results2, ActivePowerVariable, ThermalStandard)
    @test var1_a == var2
    @test get_system(results2) !== nothing

    # Serialize to a new directory with the exported function.
    results_path = joinpath(path, "results")
    serialize_results(results1, results_path)
    @test isfile(joinpath(results_path, PSI._PROBLEM_RESULTS_FILENAME))
    results3 = ProblemResults(results_path)
    var3 = read_variable(results3, ActivePowerVariable, ThermalStandard)
    @test var1_a == var3
    @test get_system(results3) === nothing
    set_system!(results3, get_system(results1))
    @test get_system(results3) !== nothing

    exp_file =
        joinpath(path, "results", "variables", "ActivePowerVariable_ThermalStandard.csv")
    var4 = PSI.read_dataframe(exp_file)
    @test var1_a == var4
end

@testset "Test deserialization and re-run of EmulationModel" begin
    path = mktempdir(cleanup = true)
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(
        PSITestSystems,
        "c_sys5_uc";
        add_single_time_series = true,
        force_build = true,
    )

    model = EmulationModel(template, c_sys5; optimizer = OSQP_optimizer)
    executions = 10
    @test build!(model; executions = executions, output_dir = path) == BuildStatus.BUILT
    @test run!(model) == RunStatus.SUCCESSFUL
    results = ProblemResults(model)
    var1 = read_variable(results, ActivePowerVariable, ThermalStandard)

    file_list = sort!(collect(readdir(path)))
    @test PSI._JUMP_MODEL_FILENAME in file_list
    @test PSI._SERIALIZED_MODEL_FILENAME in file_list
    path2 = joinpath(path, "tmp")
    model2 = EmulationModel(path, Cbc_optimizer)
    build!(model2, output_dir = path2)
    @test run!(model2) == RunStatus.SUCCESSFUL
    results2 = ProblemResults(model2)
    var2 = read_variable(results, ActivePowerVariable, ThermalStandard)

    @test var1 == var2

    # Deserialize with different optimizer attributes.
    optimizer = JuMP.optimizer_with_attributes(
        OSQP.Optimizer,
        "verbose" => true,
        "max_iter" => 60000,
    )
    @test_logs (:warn, r"Original solver used") match_mode = :any EmulationModel(
        path,
        optimizer,
    )

    # Deserialize with a different optimizer.
    @test_logs (:warn, r"Original solver was .* new solver is") match_mode = :any EmulationModel(
        path,
        GLPK_optimizer,
    )
end

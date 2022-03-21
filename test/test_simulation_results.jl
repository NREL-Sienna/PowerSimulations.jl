ED_EXPECTED_VARS = [
    "ActivePowerVariable__HydroEnergyReservoir",
    "ActivePowerVariable__RenewableDispatch",
    "ActivePowerVariable__ThermalStandard",
    "SystemBalanceSlackDown__System",
    "SystemBalanceSlackUp__System",
]

UC_EXPECTED_VARS = [
    "ActivePowerVariable__HydroEnergyReservoir",
    "ActivePowerVariable__RenewableDispatch",
    "ActivePowerVariable__ThermalStandard",
    "OnVariable__ThermalStandard",
    "StartVariable__ThermalStandard",
    "StopVariable__ThermalStandard",
]

function verify_export_results(results, export_path)
    exports = SimulationResultsExport(
        make_export_all(keys(results.decision_problem_results)),
        results.params,
    )
    export_results(results, exports)

    for problem_results in values(results.decision_problem_results)
        rpath = problem_results.results_output_folder
        problem = problem_results.problem
        for timestamp in get_timestamps(problem_results)
            for name in list_dual_names(problem_results)
                @test compare_results(rpath, export_path, problem, "duals", name, timestamp)
            end
            for name in list_parameter_names(problem_results)
                @test compare_results(
                    rpath,
                    export_path,
                    problem,
                    "parameters",
                    name,
                    timestamp,
                )
            end
            for name in list_variable_names(problem_results)
                @test compare_results(
                    rpath,
                    export_path,
                    problem,
                    "variables",
                    name,
                    timestamp,
                )
            end

            for name in list_aux_variable_names(problem_results)
                @test compare_results(
                    rpath,
                    export_path,
                    problem,
                    "aux_variables",
                    name,
                    timestamp,
                )
            end
        end

        # This file is not currently exported during the simulation.
        @test isfile(
            joinpath(
                problem_results.results_output_folder,
                problem_results.problem,
                "optimizer_stats.csv",
            ),
        )
    end
end

function compare_results(rpath, epath, model, field, name, timestamp)
    filename = string(name) * "_" * PSI.convert_for_path(timestamp) * ".csv"
    rp = joinpath(rpath, model, field, filename)
    ep = joinpath(epath, model, field, filename)
    df1 = PSI.read_dataframe(rp)
    df2 = PSI.read_dataframe(ep)
    names1 = names(df1)
    names2 = names(df2)
    names1 != names2 && return false
    size(df1) != size(df2) && return false

    for (row1, row2) in zip(eachrow(df1), eachrow(df2))
        for name in names1
            if !isapprox(row1[name], row2[name])
                @error "File mismatch" rp ep row1 row2
                return false
            end
        end
    end

    return true
end

function make_export_all(problems)
    return [
        ProblemResultsExport(
            x,
            store_all_duals=true,
            store_all_variables=true,
            store_all_aux_variables=true,
            store_all_parameters=true,
        ) for x in problems
    ]
end

function test_simulation_results(file_path::String, export_path; in_memory=false)
    @testset "Test simulation results in_memory = $in_memory" begin
        template_uc = get_template_basic_uc_simulation()
        template_ed = get_template_nomin_ed_simulation()
        set_device_model!(template_ed, InterruptibleLoad, StaticPowerLoad)
        set_device_model!(template_ed, HydroEnergyReservoir, HydroDispatchReservoirBudget)
        set_network_model!(
            template_uc,
            NetworkModel(CopperPlatePowerModel, duals=[CopperPlateBalanceConstraint]),
        )
        set_network_model!(
            template_ed,
            NetworkModel(
                CopperPlatePowerModel,
                duals=[CopperPlateBalanceConstraint],
                use_slacks=true,
            ),
        )
        c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
        c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
        models = SimulationModels(
            decision_models=[
                DecisionModel(
                    template_uc,
                    c_sys5_hy_uc;
                    name="UC",
                    optimizer=GLPK_optimizer,
                ),
                DecisionModel(
                    template_ed,
                    c_sys5_hy_ed;
                    name="ED",
                    optimizer=ipopt_optimizer,
                ),
            ],
        )

        sequence = SimulationSequence(
            models=models,
            feedforwards=Dict(
                "ED" => [
                    SemiContinuousFeedforward(
                        component_type=ThermalStandard,
                        source=OnVariable,
                        affected_values=[ActivePowerVariable],
                    ),
                    EnergyLimitFeedforward(
                        component_type=HydroEnergyReservoir,
                        source=ActivePowerVariable,
                        affected_values=[ActivePowerVariable],
                        number_of_periods=12,
                    ),
                ],
            ),
            ini_cond_chronology=InterProblemChronology(),
        )
        sim = Simulation(
            name="no_cache",
            steps=2,
            models=models,
            sequence=sequence,
            simulation_folder=file_path,
        )

        build_out = build!(sim; console_level=Logging.Error)
        @test build_out == PSI.BuildStatus.BUILT

        exports = Dict(
            "models" => [
                Dict(
                    "name" => "UC",
                    "store_all_variables" => true,
                    "store_all_parameters" => true,
                    "store_all_duals" => true,
                    "store_all_aux_variables" => true,
                ),
                Dict(
                    "name" => "ED",
                    "store_all_variables" => true,
                    "store_all_parameters" => true,
                    "store_all_duals" => true,
                    "store_all_aux_variables" => true,
                ),
            ],
            "path" => export_path,
            "optimizer_stats" => true,
        )
        execute_out = execute!(sim, exports=exports, in_memory=in_memory)
        @test execute_out == PSI.RunStatus.SUCCESSFUL

        results = SimulationResults(sim)
        test_decision_problem_results(results, c_sys5_hy_ed, c_sys5_hy_uc, in_memory)
        test_emulation_problem_results(results, in_memory)

        results_ed = get_decision_problem_results(results, "ED")
        @test !isempty(results_ed)
        @test !isempty(results)
        empty!(results)
        @test isempty(results_ed)
        @test isempty(results)

        verify_export_results(results, export_path)

        @test length(readdir(export_realized_results(results_ed))) === 18

        # Test that you can't read a failed simulation.
        PSI.set_simulation_status!(sim, RunStatus.FAILED)
        PSI.serialize_status(sim)
        @test PSI.deserialize_status(sim) == RunStatus.FAILED
        @test_throws ErrorException SimulationResults(sim)
        @test_logs(
            match_mode = :any,
            (:warn, r"Results may not be valid"),
            SimulationResults(sim, ignore_status=true),
        )

        if in_memory
            @test !isempty(
                sim.internal.store.dm_data[:ED].variables[PSI.VariableKey(
                    ActivePowerVariable,
                    ThermalStandard,
                )],
            )
            @test !isempty(sim.internal.store.dm_data[:ED].optimizer_stats)
            empty!(sim.internal.store)
            @test isempty(sim.internal.store.dm_data[:ED].variables)
            @test isempty(sim.internal.store.dm_data[:ED].optimizer_stats)
        end
    end
end

function test_decision_problem_results_values(
    results_ed,
    results_uc,
    c_sys5_hy_ed,
    c_sys5_hy_uc,
)
    @test IS.get_uuid(get_system(results_uc)) === IS.get_uuid(c_sys5_hy_uc)
    @test IS.get_uuid(get_system(results_ed)) === IS.get_uuid(c_sys5_hy_ed)

    @test isempty(setdiff(UC_EXPECTED_VARS, list_variable_names(results_uc)))
    @test isempty(setdiff(ED_EXPECTED_VARS, list_variable_names(results_ed)))

    p_thermal_standard_ed = read_variable(results_ed, ActivePowerVariable, ThermalStandard)
    @test length(keys(p_thermal_standard_ed)) == 48
    for v in values(p_thermal_standard_ed)
        @test size(v) == (12, 6)
    end

    ren_dispatch_params =
        read_parameter(results_ed, ActivePowerTimeSeriesParameter, RenewableDispatch)
    @test length(keys(ren_dispatch_params)) == 48
    for v in values(ren_dispatch_params)
        @test size(v) == (12, 4)
    end

    network_duals = read_dual(results_ed, CopperPlateBalanceConstraint, PSY.System)
    @test length(keys(network_duals)) == 48
    for v in values(network_duals)
        @test size(v) == (12, 2)
    end

    expression = read_expression(results_ed, PSI.ProductionCostExpression, ThermalStandard)
    @test length(keys(expression)) == 48
    for v in values(expression)
        @test size(v) == (12, 6)
    end

    for var_key in
        ((ActivePowerVariable, RenewableDispatch), (ActivePowerVariable, ThermalStandard))
        variable_by_initial_time = read_variable(results_uc, var_key...)
        for df in values(variable_by_initial_time)
            @test size(df)[1] == 24
        end
    end

    realized_variable_uc = read_realized_variables(results_uc)
    @test length(keys(realized_variable_uc)) == length(UC_EXPECTED_VARS)
    for var in values(realized_variable_uc)
        @test size(var)[1] == 48
    end

    realized_variable_uc =
        read_realized_variables(results_uc, [(ActivePowerVariable, ThermalStandard)])
    @test realized_variable_uc ==
          read_realized_variables(results_uc, ["ActivePowerVariable__ThermalStandard"])
    @test length(keys(realized_variable_uc)) == 1
    for var in values(realized_variable_uc)
        @test size(var)[1] == 48
    end

    realized_param_uc = read_realized_parameters(results_uc)
    @test length(keys(realized_param_uc)) == 3
    for param in values(realized_param_uc)
        @test size(param)[1] == 48
    end

    realized_param_uc = read_realized_parameters(
        results_uc,
        [(ActivePowerTimeSeriesParameter, RenewableDispatch)],
    )
    @test realized_param_uc == read_realized_parameters(
        results_uc,
        ["ActivePowerTimeSeriesParameter__RenewableDispatch"],
    )
    @test length(keys(realized_param_uc)) == 1
    for param in values(realized_param_uc)
        @test size(param)[1] == 48
    end

    realized_duals_ed = read_realized_duals(results_ed)
    @test length(keys(realized_duals_ed)) == 1
    for param in values(realized_duals_ed)
        @test size(param)[1] == 576
    end

    realized_duals_ed =
        read_realized_duals(results_ed, [(CopperPlateBalanceConstraint, System)])
    @test realized_duals_ed ==
          read_realized_duals(results_ed, ["CopperPlateBalanceConstraint__System"])
    @test length(keys(realized_duals_ed)) == 1
    for param in values(realized_duals_ed)
        @test size(param)[1] == 576
    end

    realized_duals_uc =
        read_realized_duals(results_uc, [(CopperPlateBalanceConstraint, System)])
    @test length(keys(realized_duals_uc)) == 1
    for param in values(realized_duals_uc)
        @test size(param)[1] == 48
    end

    realized_expressions = read_realized_expressions(
        results_uc,
        [(PSI.ProductionCostExpression, RenewableDispatch)],
    )
    @test realized_expressions == read_realized_expressions(
        results_uc,
        ["ProductionCostExpression__RenewableDispatch"],
    )
    @test length(keys(realized_expressions)) == 1
    for exp in values(realized_expressions)
        @test size(exp)[1] == 48
    end

    #request non sync data
    @test_logs(
        (:error, r"Requested time does not match available results"),
        match_mode = :any,
        @test_throws IS.InvalidValue read_realized_variables(
            results_ed,
            [(ActivePowerVariable, ThermalStandard)];
            start_time=DateTime("2024-01-01T02:12:00"),
            len=3,
        )
    )

    # request good window
    @test size(
        read_realized_variables(
            results_ed,
            [(ActivePowerVariable, ThermalStandard)];
            start_time=DateTime("2024-01-02T23:10:00"),
            len=10,
        )["ActivePowerVariable__ThermalStandard"],
    )[1] == 10

    # request bad window
    @test_logs(
        (:error, r"Requested time does not match available results"),
        (@test_throws IS.InvalidValue read_realized_variables(
            results_ed,
            [(ActivePowerVariable, ThermalStandard)];
            start_time=DateTime("2024-01-02T23:10:00"),
            len=11,
        ))
    )

    # request bad window
    @test_logs(
        (:error, r"Requested time does not match available results"),
        (@test_throws IS.InvalidValue read_realized_variables(
            results_ed,
            [(ActivePowerVariable, ThermalStandard)];
            start_time=DateTime("2024-01-02T23:10:00"),
            len=12,
        ))
    )

    load_results!(
        results_ed,
        3,
        initial_time=DateTime("2024-01-01T00:00:00"),
        variables=[(ActivePowerVariable, ThermalStandard)],
    )

    @test !isempty(
        results_ed.values.variables[PSI.VariableKey(ActivePowerVariable, ThermalStandard)],
    )
    @test length(
        results_ed.values.variables[PSI.VariableKey(ActivePowerVariable, ThermalStandard)],
    ) == 3
    @test length(results_ed) == 3

    @test_throws(ErrorException, read_parameter(results_ed, "invalid"))
    @test_throws(ErrorException, read_variable(results_ed, "invalid"))
    @test_logs(
        (:error, r"not stored"),
        @test_throws(
            IS.InvalidValue,
            read_variable(
                results_uc,
                ActivePowerVariable,
                ThermalStandard;
                initial_time=now(),
            )
        )
    )
    @test_logs(
        (:error, r"not stored"),
        @test_throws(
            IS.InvalidValue,
            read_variable(results_uc, ActivePowerVariable, ThermalStandard; count=25)
        )
    )

    empty!(results_ed)
    @test isempty(
        results_ed.values.variables[PSI.VariableKey(ActivePowerVariable, ThermalStandard)],
    )

    initial_time = DateTime("2024-01-01T00:00:00")
    load_results!(
        results_ed,
        3,
        initial_time=initial_time,
        variables=[(ActivePowerVariable, ThermalStandard)],
        duals=[(CopperPlateBalanceConstraint, System)],
        parameters=[(ActivePowerTimeSeriesParameter, RenewableDispatch)],
    )

    @test !isempty(
        results_ed.values.variables[PSI.VariableKey(ActivePowerVariable, ThermalStandard)],
    )
    @test !isempty(
        results_ed.values.duals[PSI.ConstraintKey(CopperPlateBalanceConstraint, System)],
    )
    @test !isempty(
        results_ed.values.parameters[PSI.ParameterKey{
            ActivePowerTimeSeriesParameter,
            RenewableDispatch,
        }(
            "",
        )],
    )
end

function test_decision_problem_results(
    results::SimulationResults,
    c_sys5_hy_ed,
    c_sys5_hy_uc,
    in_memory,
)
    @test list_decision_problems(results) == ["ED", "UC"]
    results_uc = get_decision_problem_results(results, "UC")
    results_ed = get_decision_problem_results(results, "ED")

    test_decision_problem_results_values(results_ed, results_uc, c_sys5_hy_ed, c_sys5_hy_uc)
    if !in_memory
        test_simulation_results_from_file(results.path, c_sys5_hy_ed, c_sys5_hy_uc)
    end
end

function test_emulation_problem_results(results::SimulationResults, in_memory)
    results_em = get_emulation_problem_results(results)

    read_realized_aux_variables(results_em)

    duals_keys = collect(keys(read_realized_duals(results_em)))
    @test length(duals_keys) == 1
    @test duals_keys[1] == "CopperPlateBalanceConstraint__System"
    duals_inputs =
        (["CopperPlateBalanceConstraint__System"], [(CopperPlateBalanceConstraint, System)])
    for input in duals_inputs
        duals_value = first(values(read_realized_duals(results_em, input)))
        @test duals_value isa DataFrames.DataFrame
        @test DataFrames.nrow(duals_value) == 576
    end

    expressions_keys = collect(keys(read_realized_expressions(results_em)))
    @test length(expressions_keys) == 3
    expressions_inputs = (
        [
            "ProductionCostExpression__HydroEnergyReservoir",
            "ProductionCostExpression__ThermalStandard",
        ],
        [
            (ProductionCostExpression, HydroEnergyReservoir),
            (ProductionCostExpression, ThermalStandard),
        ],
    )
    for input in expressions_inputs
        expressions_value = first(values(read_realized_expressions(results_em, input)))
        @test expressions_value isa DataFrames.DataFrame
        @test DataFrames.nrow(expressions_value) == 576
    end

    @test DataFrames.nrow(
        read_realized_expression(results_em, "ProductionCostExpression__ThermalStandard"),
    ) == 576
    @test DataFrames.nrow(
        read_realized_expression(
            results_em,
            ProductionCostExpression,
            ThermalStandard,
            len=10,
        ),
    ) == 10

    parameters_keys = collect(keys(read_realized_parameters(results_em)))
    @test length(parameters_keys) == 7
    parameters_inputs = (
        [
            "ActivePowerTimeSeriesParameter__PowerLoad",
            "ActivePowerTimeSeriesParameter__RenewableDispatch",
        ],
        [
            (ActivePowerTimeSeriesParameter, PowerLoad),
            (ActivePowerTimeSeriesParameter, RenewableDispatch),
        ],
    )
    for input in parameters_inputs
        parameters_value = first(values(read_realized_parameters(results_em, input)))
        @test parameters_value isa DataFrames.DataFrame
        @test DataFrames.nrow(parameters_value) == 576
    end

    @test DataFrames.nrow(
        read_realized_parameter(
            results_em,
            "ActivePowerTimeSeriesParameter__RenewableDispatch",
            len=10,
        ),
    ) == 10

    expected_vars = union(Set(ED_EXPECTED_VARS), UC_EXPECTED_VARS)
    @test isempty(setdiff(list_variable_names(results_em), expected_vars))
    all_vars = Set(keys(read_realized_variables(results_em)))
    @test isempty(setdiff(all_vars, expected_vars))

    variables_inputs = (
        ["ActivePowerVariable__ThermalStandard", "ActivePowerVariable__RenewableDispatch"],
        [(ActivePowerVariable, ThermalStandard), (ActivePowerVariable, RenewableDispatch)],
    )
    for input in variables_inputs
        vars = read_realized_variables(results_em, input)
        var_keys = collect(keys(vars))
        @test length(var_keys) == 2
        @test first(var_keys) == "ActivePowerVariable__ThermalStandard"
        @test last(var_keys) == "ActivePowerVariable__RenewableDispatch"
        for val in values(vars)
            @test val isa DataFrames.DataFrame
            @test DataFrames.nrow(val) == 576
        end
    end

    start_time = first(results_em.timestamps) + Dates.Hour(1)
    len = 12
    @test DataFrames.nrow(
        read_realized_variable(
            results_em,
            ActivePowerVariable,
            ThermalStandard,
            start_time=start_time,
            len=len,
        ),
    ) == len

    vars = read_realized_variables(
        results_em,
        variables_inputs[1],
        start_time=start_time,
        len=len,
    )
    df = first(values(vars))
    @test DataFrames.nrow(df) == len
    @test df[!, "DateTime"][1] == start_time

    @test_throws IS.InvalidValue read_realized_variables(
        results_em,
        variables_inputs[1],
        start_time=start_time,
        len=100000,
    )
    @test_throws IS.InvalidValue read_realized_variables(
        results_em,
        variables_inputs[1],
        start_time=start_time + Dates.Second(1),
    )
    @test_throws IS.InvalidValue read_realized_variables(
        results_em,
        variables_inputs[1],
        start_time=start_time - Dates.Hour(1000),
    )
    @test_throws IS.InvalidValue read_realized_variables(
        results_em,
        variables_inputs[1],
        len=100000,
    )

    @test isempty(results_em)
    load_results!(
        results_em,
        duals=duals_inputs[2],
        expressions=expressions_inputs[2],
        parameters=parameters_inputs[2],
        variables=variables_inputs[2],
    )
    @test !isempty(results_em)
    @test length(results_em) ==
          length(duals_inputs[2]) +
          length(expressions_inputs[2]) +
          length(parameters_inputs[2]) +
          length(variables_inputs[2])
    empty!(results_em)
    @test isempty(results_em)

    export_path = mktempdir(cleanup=true)
    export_realized_results(results_em, export_path)

    var_name = "ActivePowerVariable__ThermalStandard"
    df = read_realized_variable(results_em, var_name)
    export_active_power_file = joinpath(export_path, "$(var_name).csv")
    export_df = PSI.read_dataframe(export_active_power_file)
    # TODO: A bug in the code produces NaN after index 48.
    @test isapprox(df[48, :], export_df[48, :])
end

function test_simulation_results_from_file(path::AbstractString, c_sys5_hy_ed, c_sys5_hy_uc)
    results = SimulationResults(path)
    @test list_decision_problems(results) == ["ED", "UC"]
    results_uc = get_decision_problem_results(results, "UC")
    results_ed = get_decision_problem_results(results, "ED")

    # Verify this works without system.
    @test get_system(results_uc) === nothing
    @test length(read_realized_variables(results_uc)) == length(UC_EXPECTED_VARS)

    @test_throws IS.InvalidValue set_system!(results_uc, c_sys5_hy_ed)
    set_system!(results_ed, c_sys5_hy_ed)
    set_system!(results_uc, c_sys5_hy_uc)

    test_decision_problem_results_values(results_ed, results_uc, c_sys5_hy_ed, c_sys5_hy_uc)
end

@testset "Test simulation results" begin
    for in_memory in (false, true)
        file_path = mktempdir(cleanup=true)
        export_path = mktempdir(cleanup=true)
        test_simulation_results(file_path, export_path, in_memory=in_memory)
    end
end

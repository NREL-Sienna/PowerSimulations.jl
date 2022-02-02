function verify_export_results(results, export_path)
    exports = SimulationResultsExport(
        make_export_all(keys(results.problem_results)),
        results.params,
    )
    export_results(results, exports)

    for problem_results in values(results.problem_results)
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
            store_all_duals = true,
            store_all_variables = true,
            store_all_aux_variables = true,
            store_all_parameters = true,
        ) for x in problems
    ]
end

function test_simulation_results(file_path::String, export_path; in_memory = false)
    @testset "Test simulation results in_memory = $in_memory" begin
        template_uc = get_template_basic_uc_simulation()
        template_ed = get_template_nomin_ed_simulation()
        set_device_model!(template_ed, InterruptibleLoad, StaticPowerLoad)
        set_device_model!(template_ed, HydroEnergyReservoir, HydroDispatchReservoirBudget)
        set_network_model!(
            template_uc,
            NetworkModel(CopperPlatePowerModel, duals = [CopperPlateBalanceConstraint]),
        )
        set_network_model!(
            template_ed,
            NetworkModel(
                CopperPlatePowerModel,
                duals = [CopperPlateBalanceConstraint],
                use_slacks = true,
            ),
        )
        c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
        c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
        models = SimulationModels(
            decision_models = [
                DecisionModel(
                    template_uc,
                    c_sys5_hy_uc;
                    name = "UC",
                    optimizer = GLPK_optimizer,
                ),
                DecisionModel(
                    template_ed,
                    c_sys5_hy_ed;
                    name = "ED",
                    optimizer = ipopt_optimizer,
                ),
            ],
        )

        sequence = SimulationSequence(
            models = models,
            feedforwards = Dict(
                "ED" => [
                    SemiContinuousFeedforward(
                        component_type = ThermalStandard,
                        source = OnVariable,
                        affected_values = [ActivePowerVariable],
                    ),
                    IntegralLimitFeedforward(
                        component_type = HydroEnergyReservoir,
                        source = ActivePowerVariable,
                        affected_values = [ActivePowerVariable],
                        number_of_periods = 12,
                    ),
                ],
            ),
            ini_cond_chronology = InterProblemChronology(),
        )
        sim = Simulation(
            name = "no_cache",
            steps = 2,
            models = models,
            sequence = sequence,
            simulation_folder = file_path,
        )

        build_out = build!(sim; console_level = Logging.Error)
        @test build_out == PSI.BuildStatus.BUILT

        exports = Dict(
            "models" => [
                Dict(
                    "name" => "UC",
                    "store_all_variables" => true,
                    "store_all_parameters" => true,
                    "store_all_duals" => true,
                ),
                Dict(
                    "name" => "ED",
                    "store_all_variables" => true,
                    "store_all_parameters" => true,
                    "store_all_duals" => true,
                ),
            ],
            "path" => export_path,
            "optimizer_stats" => true,
        )
        execute_out = execute!(sim, exports = exports, in_memory = in_memory)
        @test execute_out == PSI.RunStatus.SUCCESSFUL

        results = SimulationResults(sim)
        @test list_problems(results) == ["ED", "UC"]
        results_uc = get_problem_results(results, "UC")
        results_ed = get_problem_results(results, "ED")

        ed_expected_vars = [
            "ActivePowerVariable__HydroEnergyReservoir",
            "ActivePowerVariable__RenewableDispatch",
            "ActivePowerVariable__ThermalStandard",
            "SystemBalanceSlackDown__System",
            "SystemBalanceSlackUp__System",
        ]

        uc_expected_vars = [
            "ActivePowerVariable__HydroEnergyReservoir",
            "ActivePowerVariable__RenewableDispatch",
            "ActivePowerVariable__ThermalStandard",
            "OnVariable__ThermalStandard",
            "StartVariable__ThermalStandard",
            "StopVariable__ThermalStandard",
        ]

        if in_memory
            @test IS.get_uuid(get_system(results_uc)) === IS.get_uuid(c_sys5_hy_uc)
            @test IS.get_uuid(get_system(results_ed)) === IS.get_uuid(c_sys5_hy_ed)
        else
            @test get_system(results_uc) === nothing
            #@test length(read_realized_variables(results_uc)) == 12 #verifies this works without system
            @test_throws IS.InvalidValue set_system!(results_uc, c_sys5_hy_ed)
            set_system!(results_uc, c_sys5_hy_uc)
            @test IS.get_uuid(get_system!(results_uc)) === IS.get_uuid(c_sys5_hy_uc)
            @test get_system(results_ed) === nothing
            @test IS.get_uuid(get_system!(results_ed)) === IS.get_uuid(c_sys5_hy_ed)

            results_from_file = SimulationResults(joinpath(file_path, "no_cache"))
            @test list_problems(results) == ["ED", "UC"]
            results_uc_from_file = get_problem_results(results_from_file, "UC")
            results_ed_from_file = get_problem_results(results_from_file, "ED")

            @test isempty(
                setdiff(uc_expected_vars, list_variable_names(results_uc_from_file)),
            )
            @test isempty(
                setdiff(ed_expected_vars, list_variable_names(results_ed_from_file)),
            )
        end

        @test isempty(setdiff(uc_expected_vars, list_variable_names(results_uc)))
        @test isempty(setdiff(ed_expected_vars, list_variable_names(results_ed)))
        p_thermal_standard_ed =
            read_variable(results_ed, ActivePowerVariable, ThermalStandard)
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

        expression =
            read_expression(results_ed, PSI.ProductionCostExpression, ThermalStandard)
        @test length(keys(expression)) == 48
        for v in values(expression)
            @test size(v) == (12, 6)
        end

        for var_key in (
            (ActivePowerVariable, RenewableDispatch),
            (ActivePowerVariable, ThermalStandard),
        )
            variable_by_initial_time = read_variable(results_uc, var_key...)
            for df in values(variable_by_initial_time)
                @test size(df)[1] == 24
            end
        end

        realized_variable_uc = read_realized_variables(results_uc)
        @test length(keys(realized_variable_uc)) == length(uc_expected_vars)
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
                initial_time = DateTime("2024-01-01T02:12:00"),
                count = 3,
            )
        )

        # request good window
        @test size(
            read_realized_variables(
                results_ed,
                [(ActivePowerVariable, ThermalStandard)];
                initial_time = DateTime("2024-01-02T23:10:00"),
                count = 10,
            )["ActivePowerVariable__ThermalStandard"],
        )[1] == 10

        # request bad window
        @test_logs(
            (:error, r"Requested time does not match available results"),
            (@test_throws IS.InvalidValue read_realized_variables(
                results_ed,
                [(ActivePowerVariable, ThermalStandard)];
                initial_time = DateTime("2024-01-02T23:10:00"),
                count = 11,
            ))
        )

        # request bad window
        @test_logs(
            (:error, r"Requested time does not match available results"),
            (@test_throws IS.InvalidValue read_realized_variables(
                results_ed,
                [(ActivePowerVariable, ThermalStandard)];
                initial_time = DateTime("2024-01-02T23:10:00"),
                count = 12,
            ))
        )

        load_results!(
            results_ed,
            3,
            initial_time = DateTime("2024-01-01T00:00:00"),
            variables = [(ActivePowerVariable, ThermalStandard)],
        )

        @test !isempty(
            results_ed.variable_values[PSI.VariableKey(
                ActivePowerVariable,
                ThermalStandard,
            )],
        )
        @test length(
            results_ed.variable_values[PSI.VariableKey(
                ActivePowerVariable,
                ThermalStandard,
            )],
        ) == 3
        @test length(results_ed) == 3
        @test length(results) == length(results_ed)

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
                    initial_time = now(),
                )
            )
        )
        @test_logs(
            (:error, r"not stored"),
            @test_throws(
                IS.InvalidValue,
                read_variable(results_uc, ActivePowerVariable, ThermalStandard; count = 25)
            )
        )

        empty!(results_ed)
        @test isempty(
            results_ed.variable_values[PSI.VariableKey(
                ActivePowerVariable,
                ThermalStandard,
            )],
        )

        initial_time = DateTime("2024-01-01T00:00:00")
        load_results!(
            results_ed,
            3,
            initial_time = initial_time,
            variables = [(ActivePowerVariable, ThermalStandard)],
            duals = [(CopperPlateBalanceConstraint, System)],
            parameters = [(ActivePowerTimeSeriesParameter, RenewableDispatch)],
        )

        @test !isempty(
            results_ed.variable_values[PSI.VariableKey(
                ActivePowerVariable,
                ThermalStandard,
            )],
        )
        @test !isempty(
            results_ed.dual_values[PSI.ConstraintKey(CopperPlateBalanceConstraint, System)],
        )
        @test !isempty(
            results_ed.parameter_values[PSI.ParameterKey{
                ActivePowerTimeSeriesParameter,
                RenewableDispatch,
            }(
                "",
            )],
        )

        @test !isempty(results_ed)
        @test !isempty(results)
        empty!(results)
        @test isempty(results_ed)
        @test isempty(results)

        verify_export_results(results, export_path)

        # Test that you can't read a failed simulation.
        PSI.set_simulation_status!(sim, RunStatus.FAILED)
        PSI.serialize_status(sim)
        @test PSI.deserialize_status(sim) == RunStatus.FAILED
        @test_throws ErrorException SimulationResults(sim)
        @test_logs(
            match_mode = :any,
            (:warn, r"Results may not be valid"),
            SimulationResults(sim, ignore_status = true),
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

@testset "Test simulation results" begin
    for in_memory in (true, false)
        file_path = mkpath(joinpath(pwd(), "test_simulation_results"))
        export_path = mkpath(joinpath(pwd(), "test_export_path"))
        try
            test_simulation_results(file_path, export_path, in_memory = in_memory)
        finally
            rm(file_path, force = true, recursive = true)
            rm(export_path, force = true, recursive = true)
        end
    end
end

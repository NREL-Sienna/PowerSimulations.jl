function verify_export_results(results, export_path)
    exports = SimulationResultsExport(
        make_export_all(keys(results.problem_results)),
        results.params,
    )
    export_results(results, exports)

    for problem_results in values(results.problem_results)
        rpath = problem_results.results_output_folder
        for timestamp in get_timestamps(problem_results)
            for name in list_dual_names(problem_results)
                compare_results(rpath, export_path, model, "duals", name, timestamp)
            end
            for name in list_parameter_names(problem_results)
                compare_results(rpath, export_path, model, "parameters", name, timestamp)
            end
            for name in list_variable_names(problem_results)
                compare_results(rpath, export_path, model, "variables", name, timestamp)
            end
            for name in list_aux_variable_names(problem_results)
                compare_results(rpath, export_path, model, "aux_variables", name, timestamp)
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
    df1 = PSI.read_dataframe(joinpath(rpath, model, field, filename))
    df2 = PSI.read_dataframe(joinpath(epath, model, field, filename))
    @test df1 == df2
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

function test_simulation_results_simple(file_path::String, export_path; in_memory = false)
    template_ed = get_template_nomin_ed_simulation()
    c_sys = PSB.build_system(PSITestSystems, "c_sys5_uc")
    models = SimulationModels([
        DecisionModel(template_ed, c_sys, name = "ED", optimizer = ipopt_optimizer),
    ])
    test_sequence = SimulationSequence(
        models = models,
        intervals = Dict("ED" => (Hour(24), Consecutive())),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(
        name = "consecutive",
        steps = 2,
        models = models,
        sequence = test_sequence,
        simulation_folder = file_path,
    )
    build_out = build!(sim)
    @test build_out == PSI.BuildStatus.BUILT
    exports = Dict(
        "models" => [
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
    @test list_problems(results) == ["ED"]
    results_ed = get_problem_results(results, "ED")
    @test list_variable_names(results_ed) == ["ActivePowerVariable_ThermalStandard"]
    var1 = read_variable(results_ed, "ActivePowerVariable_ThermalStandard")
    var2 = read_variable(results_ed, ActivePowerVariable, ThermalStandard)
    @test var1 == var2
end

function test_simulation_results(file_path::String, export_path; in_memory = false)
    @testset "Test simulation results" begin
        template_uc = get_template_hydro_st_uc()
        template_ed = get_template_hydro_st_ed()
        PSI.add_dual!(PSI.get_network_model(template_ed), CopperPlateBalanceConstraint)
        c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_ems_uc")
        c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ems_ed")
        time_series_cache_size = 0  # This is only for test coverage.
        models = SimulationModels(
            DecisionModel(
                template_uc,
                c_sys5_hy_uc;
                name = "UC",
                optimizer = GLPK_optimizer,
                time_series_cache_size = time_series_cache_size,
            ),
            DecisionModel(
                template_ed,
                c_sys5_hy_ed;
                name = "ED",
                optimizer = GLPK_optimizer,
                time_series_cache_size = time_series_cache_size,
            ),
        )

        sequence_cache = SimulationSequence(
            models = models,
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                "ED" => SemiContinuousFF(
                    device_type = ThermalStandard,
                    binary_source_problem = OnVariable,
                    affected_variables = [ActivePowerVariable],
                ),
                "ED" => IntegralLimitFF(
                    device_type = HydroEnergyReservoir,
                    variable_source_problem = ActivePowerVariable,
                    affected_variables = [ActivePowerVariable],
                ),
            ),
            cache = Dict(
                ("UC",) => TimeStatusChange(ThermalStandard),
                ("UC", "ED") => StoredEnergy(HydroEnergyReservoir),
            ),
            ini_cond_chronology = InterProblemChronology(),
        )
        sim = Simulation(
            name = "cache",
            steps = 2,
            models = models,
            sequence = sequence_cache,
            simulation_folder = file_path,
        )
        build_out = build!(sim)
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
            "WaterSpillageVariable_HydroEnergyReservoir",
            "ActivePowerVariable_ThermalStandard",
            "ActivePowerVariable_RenewableDispatch",
            "EnergyVariable_HydroEnergyReservoir",
            "ActivePowerVariable_InterruptibleLoad",
            "ActivePowerVariable_HydroEnergyReservoir",
        ]

        uc_expected_vars = [
            "WaterSpillageVariable_HydroEnergyReservoir",
            "ActivePowerVariable_ThermalStandard",
            "ActivePowerVariable_RenewableDispatch",
            "StartVariable_ThermalStandard",
            "StopVariable_ThermalStandard",
            "EnergyVariable_HydroEnergyReservoir",
            "ActivePowerVariable_HydroEnergyReservoir",
            "OnVariable_ThermalStandard",
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

            results_from_file = SimulationResults(joinpath(file_path, "cache"))
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
        p_thermal_standard_ed = read_variable(results_ed, :P__ThermalStandard)
        @test length(keys(p_thermal_standard_ed)) == 48
        for v in values(p_thermal_standard_ed)
            @test size(v) == (12, 6)
        end

        ren_dispatch_params = read_parameter(
            results_ed,
            "ActivePowerTimeSeriesParameter_max_active_power_RenewableDispatch",
        )
        @test length(keys(ren_dispatch_params)) == 48
        for v in values(ren_dispatch_params)
            @test size(v) == (12, 4)
        end

        network_duals = read_dual(results_ed, CopperPlateBalanceConstraint, PSY.System)
        @test length(keys(network_duals)) == 48
        for v in values(network_duals)
            @test size(v) == (12, 2)
        end

        for var_key in (
            (ActivePowerVariable, RenewableDispath),
            (ActivePowerVariable, ThermalStandard),
        )
            variable_by_initial_time = read_variable(results_uc, var_key...)
            for df in values(variable_by_initial_time)
                @test size(df)[1] == 24
            end
        end

        realized_var_uc = read_realized_variables(results_uc)
        @test length(keys(realized_var_uc)) == 12
        for var in values(realized_var_uc)
            @test size(var)[1] == 48
        end

        realized_param_uc = read_realized_parameters(
            results_uc,
            names = [:P__max_active_power__RenewableDispatch_max_active_power],
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

        # request non sync data
        @test_logs(
            (:error, r"Requested time does not match available results"),
            match_mode = :any,
            @test_throws IS.InvalidValue read_realized_variables(
                results_ed,
                names = [:P__ThermalStandard],
                initial_time = DateTime("2024-01-01T02:12:00"),
                len = 3,
            )
        )

        # request good window
        @test size(
            read_realized_variables(
                results_ed,
                names = [:P__ThermalStandard],
                initial_time = DateTime("2024-01-02T23:10:00"),
                len = 10,
            )[:P__ThermalStandard],
        )[1] == 10

        # request bad window
        @test_logs(
            (:error, r"Requested time does not match available results"),
            (@test_throws IS.InvalidValue read_realized_variables(
                results_ed,
                names = [:P__ThermalStandard],
                initial_time = DateTime("2024-01-02T23:10:00"),
                len = 11,
            ))
        )

        # request bad window
        @test_logs(
            (:error, r"Requested time does not match available results"),
            (@test_throws IS.InvalidValue read_realized_variables(
                results_ed,
                names = [:P__ThermalStandard],
                initial_time = DateTime("2024-01-02T23:10:00"),
                len = 12,
            ))
        )

        load_results!(
            results_ed,
            3,
            initial_time = DateTime("2024-01-01T00:00:00"),
            variables = [:P__ThermalStandard],
        )

        @test !isempty(results_ed.variable_values[:P__ThermalStandard])
        @test length(results_ed.variable_values[:P__ThermalStandard]) == 3
        @test length(results_ed) == 3
        @test length(results) == length(results_ed)

        @test_logs(
            (:error, r"invalid is not stored"),
            @test_throws(IS.InvalidValue, read_parameter(results_ed, :invalid))
        )
        @test_logs(
            (:error, r"invalid is not stored"),
            @test_throws(IS.InvalidValue, read_variable(results_ed, :invalid))
        )
        @test_logs(
            (:error, r"not stored"),
            @test_throws(
                IS.InvalidValue,
                read_variable(results_uc, :P__ThermalStandard; initial_time = now())
            )
        )
        @test_logs(
            (:error, r"not stored"),
            @test_throws(
                IS.InvalidValue,
                read_variable(results_uc, :P__ThermalStandard; count = 25)
            )
        )

        empty!(results_ed)
        @test isempty(results_ed.variable_values[:P__ThermalStandard])

        initial_time = DateTime("2024-01-01T00:00:00")
        load_results!(
            results_ed,
            3,
            initial_time = initial_time,
            variables = [:P__ThermalStandard],
            duals = [:CopperPlateBalance],
            parameters = [:P__max_active_power__RenewableDispatch_max_active_power],
        )

        @test !isempty(results_ed.variable_values[:P__ThermalStandard])
        @test !isempty(results_ed.dual_values[:CopperPlateBalance])
        @test !isempty(
            results_ed.parameter_values[:P__max_active_power__RenewableDispatch_max_active_power],
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
            container = sim.internal.store.data[:ED].variables[:P__ThermalStandard]
            @test !isempty(container)
            @test !isempty(sim.internal.store.optimizer_stats)
            empty!(sim.internal.store)
            @test isempty(container)
            @test isempty(sim.internal.store.optimizer_stats)
        end
    end

    @testset "Test receding horizon simulation results" begin
        template_uc = get_template_hydro_st_uc()
        c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_ems_uc")
        problems = SimulationModels(
            UC = DecisionModel(
                template_uc,
                c_sys5_hy_uc;
                optimizer = GLPK_optimizer,
                constraint_duals = [
                    ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
                ],
            ),
        )

        sequence_rh = SimulationSequence(
            problems = problems,
            intervals = Dict("UC" => (Hour(24), RecedingHorizon())),
            ini_cond_chronology = InterProblemChronology(),
        )
        sim = Simulation(
            name = "RH",
            steps = 2,
            problems = problems,
            sequence = sequence_rh,
            simulation_folder = file_path,
        )
        build_out = build!(sim)
        @test build_out == PSI.BuildStatus.BUILT

        execute_out = execute!(sim, in_memory = in_memory)
        @test execute_out == PSI.RunStatus.SUCCESSFUL

        results = SimulationResults(sim)
        @test list_problems(results) == ["UC"]
        results_rh = get_problem_results(results, "UC")

        if in_memory
            @test IS.get_uuid(get_system(results_rh)) === IS.get_uuid(c_sys5_hy_uc)
        else
            @test get_system(results_rh) === nothing
            @test length(read_realized_variables(results_rh)) == 12 #verifies this works without system
            set_system!(results_rh, c_sys5_hy_uc)
            @test IS.get_uuid(get_system!(results_rh)) === IS.get_uuid(c_sys5_hy_uc)
        end

        uc_expected_vars = [
            "WaterSpillageVariable__HydroEnergyReservoir",
            "ActivePowerVariable_ThermalStandard",
            "ActivePowerVariable_RenewableDispatch",
            "StartVariable_ThermalStandard",
            "StopVariable_ThermalStandard",
            "EnergyVariable_HydroEnergyReservoir",
            "ActivePowerVariable_HydroEnergyReservoir",
            "OnVariable_ThermalStandard",
        ]
        @test isempty(setdiff(uc_expected_vars, list_variable_names(results_rh)))

        p_thermal_standard_rh = read_variable(results_rh, :P__ThermalStandard)
        @test length(keys(p_thermal_standard_rh)) == 2
        for v in values(p_thermal_standard_rh)
            @test size(v) == (24, 6)
        end

        ren_dispatch_params = read_parameter(
            results_rh,
            :P__max_active_power__RenewableDispatch_max_active_power,
        )
        @test length(keys(ren_dispatch_params)) == 2
        for v in values(ren_dispatch_params)
            @test size(v) == (24, 4)
        end

        if !in_memory
            # this creates a container for duals but doesn't write anything because
            # it's a MIP and the duals are unavailable.
            network_duals = read_dual(results_rh, :CopperPlateBalance)
            @test length(keys(network_duals)) == 2
            for v in values(network_duals)
                @test size(v) == (24, 2)
            end
        end

        realized_var_rh = read_realized_variables(results_rh)
        @test length(keys(realized_var_rh)) == 12
        for var in values(realized_var_rh)
            @test size(var)[1] == 48
            existing_timetsamps = get_timestamps(results_rh)
            for ts in existing_timetsamps
                val_cols = setdiff(propertynames(var), [:DateTime])
                first_row = Matrix(var[var.DateTime .== ts, val_cols])
                all_rows = Matrix(
                    var[
                        (var.DateTime .>= ts) .& (var.DateTime .< ts + existing_timetsamps.step),
                        val_cols,
                    ],
                )
                @test all(first_row .== all_rows)
            end
        end

        realized_param_rh = read_realized_parameters(results_rh)
        @test length(keys(realized_param_rh)) == 4
        for var in values(realized_param_rh)
            @test size(var)[1] == 48
            existing_timetsamps = get_timestamps(results_rh)
            for ts in existing_timetsamps
                val_cols = setdiff(propertynames(var), [:DateTime])
                first_row = Matrix(var[var.DateTime .== ts, val_cols])
                all_rows = Matrix(
                    var[
                        (var.DateTime .>= ts) .& (var.DateTime .< ts + existing_timetsamps.step),
                        val_cols,
                    ],
                )
                @test all(first_row .== all_rows)
            end
        end

        if !in_memory
            realized_duals_rh = read_realized_duals(results_rh)
            @test length(keys(realized_duals_rh)) == 1
            for var in values(realized_duals_rh)
                @test size(var)[1] == 48
                existing_timetsamps = get_timestamps(results_rh)
                for ts in existing_timetsamps
                    val_cols = setdiff(propertynames(var), [:DateTime])
                    first_row = Matrix(var[var.DateTime .== ts, val_cols])
                    all_rows = Matrix(
                        var[
                            (var.DateTime .>= ts) .& (var.DateTime .< ts + existing_timetsamps.step),
                            val_cols,
                        ],
                    )
                    @test all(first_row .== all_rows)
                end
            end
        end

        # request non sync data
        @test_logs(
            (:error, r"Requested time does not match available results"),
            match_mode = :any,
            @test_throws IS.InvalidValue read_realized_variables(
                results_rh,
                names = [:P__ThermalStandard],
                initial_time = DateTime("2024-01-01T02:12:00"),
                len = 3,
            )
        )

        # request good window
        @test size(
            read_realized_variables(
                results_rh,
                names = [:P__ThermalStandard],
                initial_time = DateTime("2024-01-01T23:00:00"),
                len = 10,
            )[:P__ThermalStandard],
        )[1] == 10

        # request bad window
        @test_logs(
            (:error, r"Requested time does not match available results"),
            (@test_throws IS.InvalidValue read_realized_variables(
                results_rh,
                names = [:P__ThermalStandard],
                initial_time = DateTime("2024-01-01T23:00:00"),
                len = 26,
            ))
        )
    end
end

@testset "Test simulation results" begin
    for in_memory in (false, true)
        file_path = mkpath(joinpath(pwd(), "test_simulation_results"))
        export_path = mkpath(joinpath(pwd(), "test_export_path"))
        try
            # Use this simple version until handling of parameters is fixed.
            test_simulation_results_simple(file_path, export_path, in_memory = in_memory)
            #test_simulation_results(file_path, export_path, in_memory = in_memory)
        finally
            rm(file_path, force = true, recursive = true)
            rm(export_path, force = true, recursive = true)
        end
    end
end

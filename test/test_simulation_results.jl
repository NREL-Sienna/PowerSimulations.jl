function verify_export_results(results, export_path)
    exports = SimulationResultsExport(
        make_export_all(keys(results.problem_results)),
        results.params,
    )
    export_results(results, exports)

    for problem_results in values(results.problem_results)
        problem = problem_results.problem
        rpath = problem_results.results_output_folder
        base_path = results.path
        for timestamp in get_existing_timestamps(problem_results)
            for name in get_existing_duals(problem_results)
                compare_results(rpath, export_path, problem, "duals", name, timestamp)
            end
            for name in get_existing_parameters(problem_results)
                compare_results(rpath, export_path, problem, "parameters", name, timestamp)
            end
            for name in get_existing_variables(problem_results)
                compare_results(rpath, export_path, problem, "variables", name, timestamp)
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

function compare_results(rpath, epath, problem, field, name, timestamp)
    filename = string(name) * "_" * PSI.convert_for_path(timestamp) * ".csv"
    df1 = PSI.read_dataframe(joinpath(rpath, problem, field, filename))
    df2 = PSI.read_dataframe(joinpath(epath, problem, field, filename))
    @test df1 == df2
end

function make_export_all(problems)
    return [
        ProblemResultsExport(x, duals = [:all], variables = [:all], parameters = [:all]) for
        x in problems
    ]
end

function test_simulation_results(file_path::String, export_path)
    @testset "Test simulation results" begin
        template_uc = get_template_hydro_st_uc()
        template_ed = get_template_hydro_st_ed()
        c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
        c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
        problems = SimulationProblems(
            UC = OperationsProblem(template_uc, c_sys5_hy_uc; optimizer = GLPK_optimizer),
            ED = OperationsProblem(
                template_ed,
                c_sys5_hy_ed;
                optimizer = GLPK_optimizer,
                constraint_duals = [:CopperPlateBalance],
            ),
        )

        sequence_cache = SimulationSequence(
            problems = problems,
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :ThermalStandard) => SemiContinuousFF(
                    binary_source_problem = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
                ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFF(
                    variable_source_problem = PSI.ACTIVE_POWER,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict(
                ("UC",) => TimeStatusChange(PSY.ThermalStandard, PSI.ON),
                ("UC", "ED") => StoredEnergy(PSY.HydroEnergyReservoir, PSI.ENERGY),
            ),
            ini_cond_chronology = InterProblemChronology(),
        )
        sim = Simulation(
            name = "cache",
            steps = 2,
            problems = problems,
            sequence = sequence_cache,
            simulation_folder = file_path,
        )
        build_out = build!(sim)
        @test build_out == PSI.BuildStatus.BUILT

        exports = Dict(
            "problems" => [
                Dict(
                    "name" => "UC",
                    "variables" => [:all],
                    "parameters" => [:all],
                    "duals" => [:all],
                ),
                Dict(
                    "name" => "ED",
                    "variables" => [:all],
                    "parameters" => [:all],
                    "duals" => [:all],
                ),
            ],
            "path" => export_path,
            "optimizer_stats" => true,
        )
        execute_out = execute!(sim, exports = exports)
        @test execute_out == PSI.RunStatus.SUCCESSFUL

        results = SimulationResults(sim)
        @test list_problems(results) == ["ED", "UC"]
        results_uc = get_problem_results(results, "UC")
        results_ed = get_problem_results(results, "ED")

        @test get_system(results_uc) === nothing
        @test length(read_realized_variables(results_uc)) == 8 #verifies this works without system
        @test_throws IS.InvalidValue set_system!(results_uc, c_sys5_hy_ed)
        set_system!(results_uc, c_sys5_hy_uc)
        @test IS.get_uuid(get_system!(results_uc)) === IS.get_uuid(c_sys5_hy_uc)

        @test get_system(results_ed) === nothing
        @test IS.get_uuid(get_system!(results_ed)) === IS.get_uuid(c_sys5_hy_ed)

        results_from_file = SimulationResults(joinpath(file_path, "cache"))
        @test list_problems(results) == ["ED", "UC"]
        results_uc_from_file = get_problem_results(results_from_file, "UC")
        results_ed_from_file = get_problem_results(results_from_file, "ED")

        ed_expected_vars = [
            :Sp__HydroEnergyReservoir
            :P__ThermalStandard
            :P__RenewableDispatch
            :E__HydroEnergyReservoir
            :P__InterruptibleLoad
            :P__HydroEnergyReservoir
        ]

        uc_expected_vars = [
            :Sp__HydroEnergyReservoir
            :P__ThermalStandard
            :P__RenewableDispatch
            :start__ThermalStandard
            :stop__ThermalStandard
            :E__HydroEnergyReservoir
            :P__HydroEnergyReservoir
            :On__ThermalStandard
        ]
        @test isempty(setdiff(uc_expected_vars, get_existing_variables(results_uc)))
        @test isempty(setdiff(ed_expected_vars, get_existing_variables(results_ed)))
        @test isempty(
            setdiff(uc_expected_vars, get_existing_variables(results_uc_from_file)),
        )
        @test isempty(
            setdiff(ed_expected_vars, get_existing_variables(results_ed_from_file)),
        )

        p_thermal_standard_ed = read_variable(results_ed, :P__ThermalStandard)
        @test length(keys(p_thermal_standard_ed)) == 48
        for v in values(p_thermal_standard_ed)
            @test size(v) == (12, 6)
        end

        ren_dispatch_params =
            read_parameter(results_ed, :P__max_active_power__RenewableDispatch)
        @test length(keys(ren_dispatch_params)) == 48
        for v in values(p_thermal_standard_ed)
            @test size(v) == (12, 6)
        end

        # TODO: duals are not being stored any longer. Is that expected?
        network_duals = read_dual(results_ed, :CopperPlateBalance)
        @test length(keys(network_duals)) == 48
        for v in values(network_duals)
            @test size(v) == (12, 2)
        end

        p_variables_uc =
            read_variables(results_uc, names = [:P__RenewableDispatch, :P__ThermalStandard])
        @test length(keys(p_variables_uc)) == 2
        for var_name in values(p_variables_uc)
            for v_ in values(var_name)
                @test size(v_)[1] == 24
            end
        end

        realized_var_uc = read_realized_variables(results_uc)
        @test length(keys(realized_var_uc)) == 8
        for var in values(realized_var_uc)
            @test size(var)[1] == 48
        end

        realized_param_uc = read_realized_parameters(
            results_uc,
            names = [:P__max_active_power__RenewableDispatch],
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
            parameters = [:P__max_active_power__RenewableDispatch],
        )

        @test !isempty(results_ed.variable_values[:P__ThermalStandard])
        @test !isempty(results_ed.dual_values[:CopperPlateBalance])
        @test !isempty(results_ed.parameter_values[:P__max_active_power__RenewableDispatch])

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
    end
end

@testset "Test simulation results" begin
    file_path = mkpath(joinpath(pwd(), "test_simulation_results"))
    export_path = mkpath(joinpath(pwd(), "test_export_path"))
    try
        test_simulation_results(file_path, export_path)
    finally
        rm(file_path, force = true, recursive = true)
        rm(export_path, force = true, recursive = true)
    end
end

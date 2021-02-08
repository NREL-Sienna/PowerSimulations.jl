function verify_export_results(results, export_path)
    exports = SimulationResultsExport(
        make_export_all(keys(results.stage_results)),
        results.params,
    )
    export_results(results, exports)

    for stage_results in values(results.stage_results)
        stage = stage_results.stage
        rpath = stage_results.results_output_folder
        base_path = results.path
        for timestamp in get_existing_timestamps(stage_results)
            for name in get_existing_duals(stage_results)
                compare_results(rpath, export_path, stage, "duals", name, timestamp)
            end
            for name in get_existing_parameters(stage_results)
                compare_results(rpath, export_path, stage, "parameters", name, timestamp)
            end
            for name in get_existing_variables(stage_results)
                compare_results(rpath, export_path, stage, "variables", name, timestamp)
            end
        end
    end
end

function compare_results(rpath, epath, stage, field, name, timestamp)
    filename = string(name) * "_" * PSI.convert_for_path(timestamp) * ".csv"
    df1 = PSI.read_dataframe(joinpath(rpath, stage, field, filename))
    df2 = PSI.read_dataframe(joinpath(epath, stage, field, filename))
    @test df1 == df2
end

function make_export_all(stages)
    return [
        StageResultsExport(x, duals = [:all], variables = [:all], parameters = [:all]) for
        x in stages
    ]
end

function test_simulation_results(file_path::String, export_path)
    @testset "Test simulation results" begin
        # TODO: make a simulation that has lookahead for better results extraction tests
        c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
        c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
        stages_definition = Dict(
            "UC" => Stage(
                GenericOpProblem,
                template_hydro_st_uc,
                c_sys5_hy_uc,
                GLPK_optimizer,
            ),
            "ED" => Stage(
                GenericOpProblem,
                template_hydro_st_ed,
                c_sys5_hy_ed,
                GLPK_optimizer,
                constraint_duals = [:CopperPlateBalance],
            ),
        )

        sequence_cache = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
                ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFF(
                    variable_source_stage = PSI.ACTIVE_POWER,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict(
                ("UC",) => TimeStatusChange(PSY.ThermalStandard, PSI.ON),
                ("UC", "ED") => StoredEnergy(PSY.HydroEnergyReservoir, PSI.ENERGY),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "results_sim",
            steps = 2,
            stages = stages_definition,
            stages_sequence = sequence_cache,
            simulation_folder = file_path,
        )
        build_out = build!(sim)
        @test build_out == PSI.BuildStatus.BUILT

        exports = Dict(
            "stages" => [
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
        )
        execute_out = execute!(sim, exports = exports)
        @test execute_out == PSI.RunStatus.SUCCESSFUL

        results = SimulationResults(sim)
        @test list_stages(results) == ["ED", "UC"]
        results_uc = get_stage_results(results, "UC")
        results_ed = get_stage_results(results, "ED")

        results_from_file = SimulationResults(joinpath(file_path, "results_sim"))
        @test list_stages(results) == ["ED", "UC"]
        results_uc_from_file = get_stage_results(results_from_file, "UC")
        results_ed_from_file = get_stage_results(results_from_file, "ED")

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
        @test length(keys(realized_var_uc)) == 10
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

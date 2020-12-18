function test_simulation_results(file_path::String)
    @testset "Test simulation results" begin
        c_sys5_hy_uc = build_system("c_sys5_hy_uc")
        c_sys5_hy_ed = build_system("c_sys5_hy_ed")
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
        @test build_out == PSI.BUILT
        execute_out = execute!(sim)
        @test execute_out == PSI.SUCCESSFUL_RUN
        results_uc = SimulationResults(sim, "UC")
        results_ed = SimulationResults(sim, "ED")
        results_uc_from_file = SimulationResults(joinpath(file_path, "results_sim"), "UC")
        results_ed_from_file = SimulationResults(joinpath(file_path, "results_sim"), "ED")

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
        @test isempty(setdiff(
            uc_expected_vars,
            get_existing_variables(results_uc_from_file),
        ))
        @test isempty(setdiff(
            ed_expected_vars,
            get_existing_variables(results_ed_from_file),
        ))

        p_thermal_standard_ed = get_variable_values(results_ed, :P__ThermalStandard)
        @test length(keys(p_thermal_standard_ed)) == 24
        for v in values(p_thermal_standard_ed)
            @test size(v) == (12, 5)
        end

        ren_dispatch_params =
            get_parameter_values(results_ed, :P__max_active_power__RenewableDispatch)
        @test length(keys(ren_dispatch_params)) == 24
        for v in values(p_thermal_standard_ed)
            @test size(v) == (12, 5)
        end

        network_duals = get_dual_values(results_ed, :CopperPlateBalance)
        @test length(keys(network_duals)) == 24
        for v in values(network_duals)
            @test size(v) == (12, 1)
        end

        p_variables_uc =
            get_variables_values(results_uc, [:P__RenewableDispatch, :P__ThermalStandard])
        @test length(keys(p_variables_uc)) == 2
        for var_name in values(p_variables_uc)
            for v_ in values(var_name)
                @test size(v_)[1] == 24
            end
        end

        load_simulation_results!(
            results_ed,
            initial_time = DateTime("2024-01-01T00:00:00"),
            count = 3,
            variables = [:P__ThermalStandard],
        )

        @test !isempty(results_ed.variable_values[:P__ThermalStandard])
        @test length(results_ed.variable_values[:P__ThermalStandard]) == 3
        @test_throws IS.InvalidValue get_parameter_values(results_ed, :invalid)
        @test_throws IS.InvalidValue get_variable_values(results_ed, :invalid)
        @test_throws IS.InvalidValue get_variable_values(
            results_uc,
            :P__ThermalStandard;
            initial_time = now(),
        )
        @test_throws IS.InvalidValue get_variable_values(
            results_uc,
            :P__ThermalStandard;
            count = 25,
        )

        clear_simulation_results!(results_ed)
        @test isempty(results_ed.variable_values[:P__ThermalStandard])

        load_simulation_results!(
            results_ed,
            initial_time = DateTime("2024-01-01T00:00:00"),
            count = 3,
            variables = [:P__ThermalStandard],
            duals = [:CopperPlateBalance],
            parameters = [:P__max_active_power__RenewableDispatch],
        )

        @test !isempty(results_ed.variable_values[:P__ThermalStandard])
        @test !isempty(results_ed.dual_values[:CopperPlateBalance])
        @test !isempty(results_ed.parameter_values[:P__max_active_power__RenewableDispatch])
    end
end

@testset "Test simulation results" begin
    # Use spaces in this path because that has caused failures.
    path = mkpath(joinpath(pwd(), "test_simulation_results"))
    try
        test_simulation_results(path)
    finally
        rm(path, force = true, recursive = true)
    end
end

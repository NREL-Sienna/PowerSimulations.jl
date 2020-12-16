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
            name = "cache",
            steps = 2,
            stages = stages_definition,
            stages_sequence = sequence_cache,
            simulation_folder = file_path,
        )
        build_out = build!(sim)
        @test build_out == PSI.BUILT
        execute_out = execute!(sim)
        @test execute_out == PSI.SUCCESSFUL_RUN
        results_uc = SimulationResults(sim, "ED")
        results_ed = SimulationResults(sim, "ED")
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

function test_simulation_single_ed(file_path::String)
    @testset "Single stage sequential tests" begin
        c_sys5_uc = build_system("c_sys5_uc")
        single_stage_definition =
            Dict("ED" => Stage(GenericOpProblem, template_ed, c_sys5_uc, ipopt_optimizer))

        single_sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "ED"),
            horizons = Dict("ED" => 24),
            intervals = Dict("ED" => (Hour(24), Consecutive())),
            ini_cond_chronology = IntraStageChronology(),
        )

        sim_single = Simulation(
            name = "consecutive",
            steps = 2,
            stages = single_stage_definition,
            stages_sequence = single_sequence,
            simulation_folder = file_path,
        )
        build_out = build!(sim_single)
        @test build_out == PSI.BUILT
        execute_out = execute!(sim_single)
        @test execute_out == PSI.SUCCESSFUL_RUN
        stage_single = PSI.get_stage(sim_single, "ED")
        @test JuMP.termination_status(stage_single.internal.psi_container.JuMPmodel) in
              [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
    end
end

function test_simulation_without_caches(file_path::String)
    @testset "All stages executed - No Cache" begin
        stage_info = Dict(
            "UC" => Dict("optimizer" => GLPK_optimizer, "jump_model" => nothing),
            "ED" => Dict("optimizer" => ipopt_optimizer),
        )
        # Tests of a Simulation without Caches
        duals = [:CopperPlateBalance]
        c_sys5_hy_uc = build_system("c_sys5_hy_uc")
        c_sys5_hy_ed = build_system("c_sys5_hy_ed")
        stages_definition = Dict(
            "UC" => Stage(
                GenericOpProblem,
                template_hydro_basic_uc,
                c_sys5_hy_uc,
                stage_info["UC"]["optimizer"];
                constraint_duals = duals,
            ),
            "ED" => Stage(
                GenericOpProblem,
                template_hydro_ed,
                c_sys5_hy_ed,
                stage_info["ED"]["optimizer"];
                constraint_duals = duals,
            ),
        )

        sequence = SimulationSequence(
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
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "aggregation",
            steps = 2,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )

        build_out = build!(sim; recorders = [:simulation])
        @test build_out == PSI.BUILT
        execute_out = execute!(sim)
        @test execute_out == PSI.SUCCESSFUL_RUN
        stage_names = keys(sim.stages)

        for name in stage_names
            stage = PSI.get_stage(sim, name)
            @test JuMP.termination_status(stage.internal.psi_container.JuMPmodel) in
                  [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        end
    end
end

function test_simulation_with_cache(file_path::String)
    @testset "Simulation with Cache" begin
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
        sim_cache = Simulation(
            name = "cache",
            steps = 2,
            stages = stages_definition,
            stages_sequence = sequence_cache,
            simulation_folder = file_path,
        )
        build_out = build!(sim_cache)
        @test build_out == PSI.BUILT
        execute_out = execute!(sim_cache)
        @test execute_out == PSI.SUCCESSFUL_RUN

        var_names =
            axes(PSI.get_stage(sim_cache, "UC").internal.psi_container.variables[:On__ThermalStandard])[1]
        for name in var_names
            var =
                PSI.get_stage(sim_cache, "UC").internal.psi_container.variables[:On__ThermalStandard][
                    name,
                    24,
                ]
            cache =
                PSI.get_cache(sim_cache, TimeStatusChange, PSY.ThermalStandard).value[name]
            @test JuMP.value(var) == cache[:status]
        end

        #= RE-Write test with new results
        @testset "Test verify initial condition update using StoredEnergy cache" begin
            ic_keys = [PSI.ICKey(PSI.EnergyLevel, PSY.HydroEnergyReservoir)]
            vars_names = [PSI.make_variable_name(PSI.ENERGY, PSY.HydroEnergyReservoir)]
            for (ik, key) in enumerate(ic_keys)
                variable_ref =
                    PSI.get_reference(sim_cache_results, "ED", 1, vars_names[ik])[end]
                initial_conditions =
                    get_initial_conditions(PSI.get_psi_container(sim_cache, "UC"), key)
                for ic in initial_conditions
                    raw_result =
                        PSI.read_arrow_file(variable_ref)[end, Symbol(PSI.device_name(ic))] # last value of last hour
                    initial_cond = value(PSI.get_value(ic))
                    @test isapprox(raw_result, initial_cond)
                end
            end
        end
        =#
    end
end

function test_simulation_utils(file_path)
    stage_info = Dict(
        "UC" => Dict("optimizer" => GLPK_optimizer, "jump_model" => nothing),
        "ED" => Dict("optimizer" => ipopt_optimizer),
    )
    duals = [:CopperPlateBalance]
    c_sys5_hy_uc = build_system("c_sys5_hy_uc")
    c_sys5_hy_ed = build_system("c_sys5_hy_ed")
    stages_definition = Dict(
        "UC" => Stage(
            GenericOpProblem,
            template_hydro_basic_uc,
            c_sys5_hy_uc,
            stage_info["UC"]["optimizer"];
            constraint_duals = duals,
        ),
        "ED" => Stage(
            GenericOpProblem,
            template_hydro_ed,
            c_sys5_hy_ed,
            stage_info["ED"]["optimizer"];
            constraint_duals = duals,
        ),
    )

    sequence = SimulationSequence(
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
        ini_cond_chronology = InterStageChronology(),
    )
    sim = Simulation(
        name = "aggregation",
        steps = 2,
        stages = stages_definition,
        stages_sequence = sequence,
        simulation_folder = file_path,
    )
    build_out = build!(sim; recorders = [:simulation])
    @test build_out == PSI.BUILT
    execute_out = execute!(sim)
    @test execute_out == PSI.SUCCESSFUL_RUN

    @testset "Verify simulation events" begin
            file = joinpath(
                PSI.get_simulation_dir(sim),
                "recorder",
                "simulation.log",
            )
            @test isfile(file)
            events = PSI.list_simulation_events(
                PSI.InitialConditionUpdateEvent,
                PSI.get_simulation_dir(sim);
                step = 1,
            )
            @test length(events) == 0
            events = PSI.list_simulation_events(
                PSI.InitialConditionUpdateEvent,
                PSI.get_simulation_dir(sim);
                step = 2,
            )
            @test length(events) == 10
            PSI.show_simulation_events(
                devnull,
                PSI.InitialConditionUpdateEvent,
                PSI.get_simulation_dir(sim),;
                step = 2,
            )
            events = PSI.list_simulation_events(
                PSI.InitialConditionUpdateEvent,
                PSI.get_simulation_dir(sim);
                step = 1,
                stage = 1,
            )
            @test length(events) == 0
            events = PSI.list_simulation_events(
                PSI.InitialConditionUpdateEvent,
                PSI.get_simulation_dir(sim),;
                step = 2,
                stage = 1,
            )
            @test length(events) == 10
            PSI.show_simulation_events(
                devnull,
                PSI.InitialConditionUpdateEvent,
                PSI.get_simulation_dir(sim),;
                step = 2,
                stage = 1,
            )
        end

    @testset "Check Serialization - Deserialization of Sim" begin
        path = mktempdir()
        files_path = PSI.serialize_simulation(sim; path = path)
        deserialized_sim = Simulation(files_path, stage_info)
        build_out = build!(deserialized_sim)
        @test build_out == PSI.BUILT
        for stage in values(PSI.get_stages(deserialized_sim))
            @test PSI.is_stage_built(stage)
        end
    end


end

@testset "Test simulation execution" begin
    # Use spaces in this path because that has caused failures.
    path = mkpath(joinpath(pwd(), "test_simulation_results"))
    test_set = [
        test_simulation_single_ed,
        test_simulation_without_caches,
        test_simulation_with_cache,
        test_simulation_utils
    ]
    try
        for f in test_set
            test_folder = mkpath(joinpath(path, randstring()))
            try
                f(test_folder)
            finally
                rm(test_folder, force = true, recursive = true)
            end
        end
    finally
        @info("removing test files")
        rm(path, force = true, recursive = true)
    end
end

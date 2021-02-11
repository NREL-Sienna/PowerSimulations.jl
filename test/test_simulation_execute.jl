function test_simulation_single_ed(file_path::String)
     @testset "Single stage sequential tests" begin
    template_ed = get_template_nomin_ed_simulation()
    c_sys = PSB.build_system(PSITestSystems, "c_sys5_uc")
    problems = SimulationProblems(
            ED = OperationsProblem(template_ed, c_sys, optimizer = ipopt_optimizer),
        )
    test_sequence = SimulationSequence(
        problems = problems,
        intervals = Dict("ED" => (Hour(24), Consecutive())),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim_single = Simulation(
        name = "consecutive",
        steps = 2,
        problems = problems,
        sequence = test_sequence,
        simulation_folder = file_path,
    )
        build_out = build!(sim_single)
        @test build_out == PSI.BuildStatus.BUILT
        execute_out = execute!(sim_single)
        @test execute_out == PSI.RunStatus.SUCCESSFUL
        #stage_single = PSI.get_stage(sim_single, "ED")
        #@test JuMP.termination_status(
        #    stage_single.internal.optimization_container.JuMPmodel,
        #) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        #_test_plain_print_methods([sim_single, sim_single.sequence])
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
        c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
        c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
        stages_definition = Dict(
            "UC" => OperationsProblem(
                GenericOpProblem,
                template_hydro_basic_uc,
                c_sys5_hy_uc,
                stage_info["UC"]["optimizer"];
                constraint_duals = duals,
            ),
            "ED" => OperationsProblem(
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
                    binary_source_problem = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
                ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFF(
                    variable_source_stage = PSI.ACTIVE_POWER,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterProblemChronology(),
        )
        sim = Simulation(
            name = "aggregation",
            steps = 2,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )

        build_out = build!(sim; recorders = [:simulation])
        @test build_out == PSI.BuildStatus.BUILT
        execute_out = execute!(sim)
        @test execute_out == PSI.RunStatus.SUCCESSFUL
        stage_names = keys(sim.stages)

        for name in stage_names
            stage = PSI.get_stage(sim, name)
            @test JuMP.termination_status(
                stage.internal.optimization_container.JuMPmodel,
            ) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        end
    end
end

function test_simulation_with_cache(file_path::String)
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    @testset "Simulation Single Stage with Cache" begin
        single_stage_definition = Dict(
            "ED" => OperationsProblem(
                GenericOpProblem,
                template_hydro_st_ed,
                c_sys5_hy_ed,
                GLPK_optimizer,
            ),
        )

        single_sequence = SimulationSequence(
            step_resolution = Hour(1),
            order = Dict(1 => "ED"),
            horizons = Dict("ED" => 12),
            intervals = Dict("ED" => (Hour(1), Consecutive())),
            cache = Dict(("ED",) => StoredEnergy(PSY.HydroEnergyReservoir, PSI.ENERGY)),
            ini_cond_chronology = IntraProblemChronology(),
        )

        sim_single_wcache = Simulation(
            name = "cache_st",
            steps = 2,
            stages = single_stage_definition,
            stages_sequence = single_sequence,
            simulation_folder = file_path,
        )
        build_out = build!(sim_single_wcache)
        @test build_out == PSI.BuildStatus.BUILT
        execute_out = execute!(sim_single_wcache)
        @test execute_out == PSI.RunStatus.SUCCESSFUL

        #=
        @testset "Test verify initial condition update using StoredEnergy cache" begin
            ic_keys = [PSI.ICKey(PSI.EnergyLevel, PSY.HydroEnergyReservoir)]
            vars_names = [PSI.make_variable_name(PSI.ENERGY, PSY.HydroEnergyReservoir)]
            for (ik, key) in enumerate(ic_keys)
                variable_ref =
                    PSI.get_reference(sim_cache_results, "ED", 1, vars_names[ik])[1]
                initial_conditions =
                    get_initial_conditions(PSI.get_optimization_container(sim_single, "ED"), key)
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

    @testset "Simulation with 2-Stages and Cache" begin
        stages_definition = Dict(
            "UC" => OperationsProblem(
                GenericOpProblem,
                template_hydro_st_uc,
                c_sys5_hy_uc,
                GLPK_optimizer,
            ),
            "ED" => OperationsProblem(
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
                    binary_source_problem = PSI.ON,
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
            ini_cond_chronology = InterProblemChronology(),
        )
        sim_cache = Simulation(
            name = "cache",
            steps = 2,
            stages = stages_definition,
            stages_sequence = sequence_cache,
            simulation_folder = file_path,
        )
        build_out = build!(sim_cache)
        @test build_out == PSI.BuildStatus.BUILT
        execute_out = execute!(sim_cache)
        @test execute_out == PSI.RunStatus.SUCCESSFUL

        var_names = axes(
            PSI.get_stage(sim_cache, "UC").internal.optimization_container.variables[:On__ThermalStandard],
        )[1]
        for name in var_names
            var =
                PSI.get_stage(sim_cache, "UC").internal.optimization_container.variables[:On__ThermalStandard][
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
                    get_initial_conditions(PSI.get_optimization_container(sim_cache, "UC"), key)
                for ic in initial_conditions
                    raw_result =
                        PSI.read_arrow_file(variable_ref)[end, Symbol(PSI.device_name(ic))] # last value of last hour
                    initial_cond = value(PSI.get_value(ic))
                    @test isapprox(raw_result, initial_cond)
                end
            end
        end

        @testset "Test verify initial condition feedforward for consecutive ED to UC" begin
            ic_keys = [PSI.ICKey(PSI.DevicePower, PSY.ThermalStandard)]
            vars_names = [PSI.make_variable_name(PSI.ACTIVE_POWER, PSY.ThermalStandard)]
            for (ik, key) in enumerate(ic_keys)
                variable_ref = PSI.get_reference(sim_results, "ED", 1, vars_names[ik])[24]
                initial_conditions =
                    get_initial_conditions(PSI.get_optimization_container(sim, "UC"), key)
                for ic in initial_conditions
                    name = PSI.device_name(ic)
                    raw_result = PSI.read_arrow_file(variable_ref)[end, Symbol(name)] # last value of last hour
                    initial_cond = value(PSI.get_value(ic))
                    @test isapprox(raw_result, initial_cond; atol = 1e-2)
                end
            end
        end

        @testset "Test verify parameter feedforward for consecutive UC to ED" begin
            P_keys = [
                (PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
                #(PSI.ON, PSY.ThermalStandard),
                #(PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
            ]

            vars_names = [
                PSI.make_variable_name(PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
                #PSI.make_variable_name(PSI.ON, PSY.ThermalStandard),
                #PSI.make_variable_name(PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
            ]
            for (ik, key) in enumerate(P_keys)
                variable_ref = PSI.get_reference(sim_results, "UC", 1, vars_names[ik])[1] # 1 is first step
                array = PSI.get_parameter_array(PSI.get_parameter_container(
                    sim.stages["ED"].internal.optimization_container,
                    Symbol(key[1]),
                    key[2],
                ))
                parameter = collect(values(value.(array.data)))  # [device, time] 1 is first execution
                raw_result = PSI.read_arrow_file(variable_ref)
                for j in 1:size(parameter, 1)
                    result = raw_result[end, j] # end is last result [time, device]
                    initial = parameter[1] # [device, time]
                    @test isapprox(initial, result)
                end
            end
        end

        =#

    end
end

function test_stage_chronologies(file_path)
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    stages_definition = Dict(
        "UC" => OperationsProblem(
            GenericOpProblem,
            template_hydro_basic_uc,
            c_sys5_hy_uc,
            GLPK_optimizer,
        ),
        "ED" => OperationsProblem(
            GenericOpProblem,
            template_hydro_ed,
            c_sys5_hy_ed,
            ipopt_optimizer,
        ),
    )

    sequence = SimulationSequence(
        order = Dict(1 => "UC", 2 => "ED"),
        step_resolution = Hour(24),
        feedforward_chronologies = Dict(("UC" => "ED") => RecedingHorizon()),
        horizons = Dict("UC" => 24, "ED" => 12),
        intervals = Dict(
            "UC" => (Hour(24), RecedingHorizon()),
            "ED" => (Minute(60), RecedingHorizon()),
        ),
        feedforward = Dict(
            ("ED", :devices, :Generators) => SemiContinuousFF(
                binary_source_problem = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    sim = Simulation(
        name = "receding_horizon",
        steps = 2,
        stages = stages_definition,
        stages_sequence = sequence,
        simulation_folder = file_path,
    )
    build_out = build!(sim)
    @test build_out == PSI.BuildStatus.BUILT
    execute_out = execute!(sim)
    @test execute_out == PSI.RunStatus.SUCCESSFUL

    #=
    @testset "Test verify time gap for Receding Horizon" begin
        names = ["UC"] # TODO why doesn't this work for ED??
        for name in names
            variable_list = PSI.get_variable_names(sim, name)
            reference_1 = PSI.get_reference(sim_results, name, 1, variable_list[1])[1]
            reference_2 = PSI.get_reference(sim_results, name, 2, variable_list[1])[1]
            time_file_path_1 = joinpath(dirname(reference_1), "time_stamp.arrow") #first line, file path
            time_file_path_2 = joinpath(dirname(reference_2), "time_stamp.arrow")
            time_1 = convert(Dates.DateTime, PSI.read_arrow_file(time_file_path_1)[1, 1]) # first time
            time_2 = convert(Dates.DateTime, PSI.read_arrow_file(time_file_path_2)[1, 1])
            time_change = time_2 - time_1
            interval = PSI.get_stage_interval(PSI.get_sequence(sim), name)
            @test Dates.Hour(time_change) == Dates.Hour(interval)
        end
    end

    @testset "Test verify parameter feedforward for Receding Horizon" begin
        P_keys = [(PSI.ON, PSY.ThermalStandard)]
        vars_names = [PSI.make_variable_name(PSI.ON, PSY.ThermalStandard)]
        for (ik, key) in enumerate(P_keys)
            variable_ref = PSI.get_reference(sim_results, "UC", 2, vars_names[ik])[1]
            raw_result = PSI.read_arrow_file(variable_ref)
            ic = PSI.get_parameter_array(PSI.get_parameter_container(
                sim.stages["ED"].internal.optimization_container,
                Symbol(key[1]),
                key[2],
            ))
            for name in names(raw_result)
                result = raw_result[1, name] # first time period of results  [time, device]
                initial = value(ic[String(name)]) # [device, time]
                @test isapprox(initial, result, atol = 1.0e-4)
            end
        end
    end

    @testset "Test verify initial condition feedforward for Receding Horizon" begin
        results = load_simulation_results(sim_results, "ED")
        ic_keys = [PSI.ICKey(PSI.DevicePower, PSY.ThermalStandard)]
        vars_names = [PSI.make_variable_name(PSI.ACTIVE_POWER, PSY.ThermalStandard)]
        ed_horizon = PSI.get_stage_horizon(sim.sequence, "ED")
        no_steps = PSI.get_steps(sim)
        for (ik, key) in enumerate(ic_keys)
            initial_conditions =
                get_initial_conditions(PSI.get_optimization_container(sim, "UC"), key)
            vars = results.variable_values[vars_names[ik]] # change to getter function
            for ic in initial_conditions
                output = vars[ed_horizon * (no_steps - 1), Symbol(PSI.device_name(ic))] # change to getter function
                initial_cond = value(PSI.get_value(ic))
                @test isapprox(output, initial_cond, atol = 1.0e-4)
            end
        end
    end
    =#
end

function test_simulation_utils(file_path)
    stage_info = Dict(
        "UC" => Dict("optimizer" => GLPK_optimizer, "jump_model" => nothing),
        "ED" => Dict("optimizer" => ipopt_optimizer),
    )
    duals = [:CopperPlateBalance]
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    stages_definition = Dict(
        "UC" => OperationsProblem(
            GenericOpProblem,
            template_hydro_basic_uc,
            c_sys5_hy_uc,
            stage_info["UC"]["optimizer"];
            constraint_duals = duals,
        ),
        "ED" => OperationsProblem(
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
                binary_source_problem = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
            ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFF(
                variable_source_stage = PSI.ACTIVE_POWER,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(
        name = "aggregation",
        steps = 2,
        stages = stages_definition,
        stages_sequence = sequence,
        simulation_folder = file_path,
    )
    build_out = build!(sim; recorders = [:simulation])
    @test build_out == PSI.BuildStatus.BUILT
    execute_out = execute!(sim)
    @test execute_out == PSI.RunStatus.SUCCESSFUL

    @testset "Verify simulation events" begin
        file = joinpath(PSI.get_simulation_dir(sim), "recorder", "simulation.log")
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
            PSI.get_simulation_dir(sim),
            ;
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
            PSI.get_simulation_dir(sim),
            ;
            step = 2,
            stage = 1,
        )
        @test length(events) == 10
        PSI.show_simulation_events(
            devnull,
            PSI.InitialConditionUpdateEvent,
            PSI.get_simulation_dir(sim),
            ;
            step = 2,
            stage = 1,
        )
    end

    @testset "Check Serialization - Deserialization of Sim" begin
        path = mktempdir()
        files_path = PSI.serialize_simulation(sim; path = path)
        deserialized_sim = Simulation(files_path, stage_info)
        build_out = build!(deserialized_sim)
        @test build_out == PSI.BuildStatus.BUILT
        for stage in values(PSI.get_stages(deserialized_sim))
            @test PSI.is_stage_built(stage)
        end
    end

    @testset "Test print methods" begin
        list = [sim, sim.sequence, sim.stages["UC"]]
        _test_plain_print_methods(list)
    end
end

@testset "Test simulation execution" begin
    test_set = [
        test_simulation_single_ed,
        # test_simulation_without_caches,
        # test_simulation_with_cache,
        # test_stage_chronologies,
        # test_simulation_utils,
    ]
    for f in test_set
        f(mktempdir(cleanup = true))
    end

end

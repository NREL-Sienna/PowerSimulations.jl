path = (joinpath(pwd(), "test_reading_results"))
!isdir(path) && mkdir(path)

function test_load_simulation(file_path::String)

    single_stage_definition =
        Dict("ED" => Stage(GenericOpProblem, template_ed, c_sys5_uc, GLPK_optimizer))

    single_sequence = SimulationSequence(
        step_resolution = Hour(1),
        order = Dict(1 => "ED"),
        horizons = Dict("ED" => 12),
        intervals = Dict("ED" => (Hour(1), Consecutive())),
        ini_cond_chronology = IntraStageChronology(),
    )

    sim_single = Simulation(
        name = "consecutive",
        steps = 2,
        stages = single_stage_definition,
        stages_sequence = single_sequence,
        simulation_folder = file_path,
    )
    build!(sim_single)
    execute!(sim_single)

    @testset "Single stage sequential tests" begin
        stage_single = PSI.get_stage(sim_single, "ED")
        @test JuMP.termination_status(stage_single.internal.psi_container.JuMPmodel) in
              [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]

    end

    # Tests of a Simulation without Caches
    duals = [:CopperPlateBalance]
    stages_definition = Dict(
        "UC" => Stage(
            GenericOpProblem,
            template_hydro_basic_uc,
            c_sys5_hy_uc,
            GLPK_optimizer,
        ),
        "ED" =>     Stage(GenericOpProblem, template_hydro_ed, c_sys5_hy_ed, GLPK_optimizer),
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
                binary_from_stage = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
            ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFF(
                variable_from_stage = PSI.ACTIVE_POWER,
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
    build!(sim)
    sim_results = execute!(sim; constraints_duals = duals)
    stage_names = keys(sim.stages)
    step = ["step-1", "step-2"]

    @testset "All stages executed - No Cache" begin
        for name in stage_names
            stage = PSI.get_stage(sim, name)
            @test JuMP.termination_status(stage.internal.psi_container.JuMPmodel) in
                  [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
        end
    end

    @testset "Test reading and writing to the results folder" begin
        for name in stage_names
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            rm(sim_results.results_folder)
            res = load_simulation_results(sim_results, name)
            !ispath(res.results_folder) && mkdir(res.results_folder)
            write_results(res)
            loaded_res = load_operation_results(sim_results.results_folder)
            @test loaded_res.variable_values == res.variable_values
        end
    end

    @testset "Test file names" begin
        for name in stage_names
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            res = load_simulation_results(sim_results, name)
            write_results(res)
            variable_list = String.(PSI.get_variable_names(sim, name))
            variable_list = [
                variable_list
                "dual_CopperPlateBalance"
                "optimizer_log"
                "time_stamp"
                "check"
                "base_power"
                "parameter_P_InterruptibleLoad"
                "parameter_P_PowerLoad"
                "parameter_P_RenewableDispatch"
                "parameter_P_HydroEnergyReservoir"
            ]
            file_list = collect(readdir(sim_results.results_folder))
            for name in file_list
                variable = splitext(name)[1]
                @test any(x -> x == variable, variable_list)
            end
        end
    end

    @testset "Test argument errors" begin
        for name in stage_names
            res = load_simulation_results(sim_results, name)
            if isdir(res.results_folder)
                files = collect(readdir(res.results_folder))
                for f in files
                    rm("$(res.results_folder)/$f")
                end
                rm("$(res.results_folder)")
            end
            @test_throws IS.ConflictingInputsError write_results(res)
        end
    end

    @testset "Test simulation output serialization and deserialization" begin
        output_path = joinpath(dirname(sim_results.results_folder), "output_references")
        sim_output = collect(readdir(output_path))
        @test sim_output == [
            "base_power.json",
            "chronologies.json",
            "results_folder.json",
            "stage-ED",
            "stage-UC",
        ]
        sim_test = PSI.deserialize_sim_output(dirname(output_path))
        @test sim_test.ref == sim_results.ref
    end

    @testset "Test load simulation results between the two methods of load simulation" begin
        for name in stage_names
            variable = PSI.get_variable_names(sim, name)
            results = load_simulation_results(sim_results, name)
            res = load_simulation_results(sim_results, name, step, variable)
            @test results.variable_values == res.variable_values
        end
    end

    @testset "Test to verify length of time_stamp" begin
        for name in keys(sim.stages)
            results = load_simulation_results(sim_results, name)
            @test size(unique(results.time_stamp), 1) == size(results.time_stamp, 1)
        end
    end

    @testset "Test to verify no gaps in the time_stamp" begin
        for name in keys(sim.stages)
            stage = sim.stages[name]
            results = load_simulation_results(sim_results, name)
            resolution =
                convert(Dates.Millisecond, PSY.get_forecasts_resolution(PSI.get_sys(stage)))
            time_stamp = results.time_stamp
            length = size(time_stamp, 1)
            test = results.time_stamp[1, 1]:resolution:results.time_stamp[length, 1]
            @test time_stamp[!, :Range] == test
        end
    end
    ###########################################################

    @testset "Test dual constraints in results" begin
        res = PSI.load_simulation_results(sim_results, "ED")
        dual =
            JuMP.dual(sim.stages["ED"].internal.psi_container.constraints[:CopperPlateBalance][1])
        @test isapprox(dual, res.dual_values[:dual_CopperPlateBalance][1, 1], atol = 1.0e-4)
        !ispath(res.results_folder) && mkdir(res.results_folder)
        PSI.write_to_CSV(res)
        @test !isempty(res.results_folder)
    end

    @testset "Test to verify parameter feedforward for consecutive UC to ED" begin
        P_keys = [
            (PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
            #(PSI.ON, PSY.ThermalStandard),
            #(PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
        ]

        vars_names = [
            PSI.variable_name(PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
            #PSI.variable_name(PSI.ON, PSY.ThermalStandard),
            #PSI.variable_name(PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
        ]
        for (ik, key) in enumerate(P_keys)
            variable_ref = PSI.get_reference(sim_results, "UC", 1, vars_names[ik])[1] # 1 is first step
            array = PSI.get_parameter_array(PSI.get_parameter_container(
                sim.stages["ED"].internal.psi_container,
                Symbol(key[1]),
                key[2],
            ))
            parameter = collect(values(value.(array.data)))  # [device, time] 1 is first execution
            raw_result = Feather.read(variable_ref)
            for i in 1:size(parameter, 1)
                result = raw_result[end, i] # end is last result [time, device]
                initial = parameter[1] # [device, time]
                @test isapprox(initial, result)
            end
        end
    end

    @testset "Testing to verify time gap for Consecutive" begin
        names = ["UC"]
        for name in names
            variable_list = PSI.get_variable_names(sim, name)
            reference_1 = PSI.get_reference(sim_results, name, 1, variable_list[1])[1]
            reference_2 = PSI.get_reference(sim_results, name, 2, variable_list[1])[1]
            time_file_path_1 = joinpath(dirname(reference_1), "time_stamp.feather") #first line, file path
            time_file_path_2 = joinpath(dirname(reference_2), "time_stamp.feather")
            time_1 = convert(Dates.DateTime, Feather.read(time_file_path_1)[end, 1]) # first time
            time_2 = convert(Dates.DateTime, Feather.read(time_file_path_2)[1, 1])
            @test time_2 == time_1
        end
    end

    @testset "Testing to verify initial condition feedforward for consecutive ED to UC" begin
        ic_keys = [PSI.ICKey(PSI.DevicePower, PSY.ThermalStandard)]
        vars_names = [PSI.variable_name(PSI.ACTIVE_POWER, PSY.ThermalStandard)]
        for (ik, key) in enumerate(ic_keys)
            variable_ref = PSI.get_reference(sim_results, "ED", 1, vars_names[ik])[24]
            initial_conditions =
                get_initial_conditions(PSI.get_psi_container(sim, "UC"), key)
            for ic in initial_conditions
                raw_result = Feather.read(variable_ref)[end, Symbol(PSI.device_name(ic))] # last value of last hour
                initial_cond = value(PSI.get_value(ic))
                @test isapprox(raw_result, initial_cond)
            end
        end
    end
    ####################

    sequence = SimulationSequence(
        order = Dict(1 => "UC", 2 => "ED"),
        step_resolution = Hour(1),
        feedforward_chronologies = Dict(("UC" => "ED") => RecedingHorizon()),
        horizons = Dict("UC" => 24, "ED" => 12),
        intervals = Dict(
            "UC" => (Hour(1), RecedingHorizon()),
            "ED" => (Minute(5), RecedingHorizon()),
        ),
        feedforward = Dict(
            ("ED", :devices, :Generators) => SemiContinuousFF(
                binary_from_stage = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        ini_cond_chronology = InterStageChronology(),
    )

    sim = Simulation(
        name = "receding_results",
        steps = 2,
        stages = stages_definition,
        stages_sequence = sequence,
        simulation_folder = file_path,
    )
    build!(sim)
    sim_results = execute!(sim)

    @testset "Testing to verify time gap for Receding Horizon" begin
        names = ["UC"] # TODO why doesn't this work for ED??
        for name in names
            variable_list = PSI.get_variable_names(sim, name)
            reference_1 = PSI.get_reference(sim_results, name, 1, variable_list[1])[1]
            reference_2 = PSI.get_reference(sim_results, name, 2, variable_list[1])[1]
            time_file_path_1 = joinpath(dirname(reference_1), "time_stamp.feather") #first line, file path
            time_file_path_2 = joinpath(dirname(reference_2), "time_stamp.feather")
            time_1 = convert(Dates.DateTime, Feather.read(time_file_path_1)[1, 1]) # first time
            time_2 = convert(Dates.DateTime, Feather.read(time_file_path_2)[1, 1])
            time_change = time_2 - time_1
            interval = PSI.get_stage_interval(PSI.get_sequence(sim), name)
            @test Dates.Hour(time_change) == Dates.Hour(interval)
        end
    end

    @testset "Testing to verify parameter feedforward for Receding Horizon" begin
        P_keys = [(PSI.ON, PSY.ThermalStandard)]
        vars_names = [PSI.variable_name(PSI.ON, PSY.ThermalStandard)]
        for (ik, key) in enumerate(P_keys)
            variable_ref = PSI.get_reference(sim_results, "UC", 2, vars_names[ik])[1]
            raw_result = Feather.read(variable_ref)
            ic = PSI.get_parameter_array(PSI.get_parameter_container(
                sim.stages["ED"].internal.psi_container,
                Symbol(key[1]),
                key[2],
            ))
            for name in DataFrames.names(raw_result)
                result = raw_result[1, name] # first time period of results  [time, device]
                initial = value(ic[String(name)]) # [device, time]
                @test isapprox(initial, result, atol = 1.0e-4)
            end
        end
    end

    @testset "Testing to verify initial condition feedforward for Receding Horizon" begin
        results = load_simulation_results(sim_results, "ED")
        ic_keys = [PSI.ICKey(PSI.DevicePower, PSY.ThermalStandard)]
        vars_names = [PSI.variable_name(PSI.ACTIVE_POWER, PSY.ThermalStandard)]
        for (ik, key) in enumerate(ic_keys)
            initial_conditions =
                get_initial_conditions(PSI.get_psi_container(sim, "UC"), key)
            vars = results.variable_values[vars_names[ik]] # change to getter function
            for ic in initial_conditions
                output = vars[1, Symbol(PSI.device_name(ic))] # change to getter function
                initial_cond = value(PSI.get_value(ic))
                @test isapprox(output, initial_cond, atol = 1e-4)
            end
        end
    end

    ####################
    @testset "negative test checking total sums" begin
        stage_names = keys(sim.stages)
        for name in stage_names
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            variable_list = PSI.get_variable_names(sim, name)
            res = load_simulation_results(sim_results, name)
            write_results(res)
            _file_path = joinpath(sim_results.results_folder, "$(variable_list[1]).feather")
            rm(_file_path)
            fake_df = DataFrames.DataFrame(:A => Array(1:10))
            Feather.write(_file_path, fake_df)
            @test_logs(
                (:error, r"hash mismatch"),
                match_mode = :any,
                @test_throws(
                    IS.HashMismatchError,
                    check_file_integrity(dirname(_file_path))
                )
            )
        end
        for name in stage_names
            variable_list = PSI.get_variable_names(sim, name)
            check_file_path = PSI.get_reference(sim_results, name, 1, variable_list[1])[1]
            rm(check_file_path)
            time_length = sim_results.chronologies["stage-$name"]
            fake_df = DataFrames.DataFrame(:A => Array(1:time_length))
            Feather.write(check_file_path, fake_df)
            @test_logs(
                (:error, r"hash mismatch"),
                match_mode = :any,
                @test_throws(
                    IS.HashMismatchError,
                    check_file_integrity(dirname(check_file_path))
                )
            )
        end
    end

    @testset "Simulation with Cache" begin
        stages_definition = Dict(
            "UC" => Stage(
                GenericOpProblem,
                template_hydro_standard_uc,
                #template_uc,
                c_sys5_hy_uc,
                #c_sys5_uc,
                GLPK_optimizer,
            ),
            "ED" => Stage(
                GenericOpProblem,
                template_hydro_ed,
                #template_ed,
                c_sys5_hy_ed,
                #c_sys5_ed,
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
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
                ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFF(
                    variable_from_stage = PSI.ACTIVE_POWER,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict("UC" => [TimeStatusChange(PSY.ThermalStandard, PSI.ON)]),
            ini_cond_chronology = InterStageChronology(),
        )
        sim_cache = Simulation(
            name = "cache",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence_cache,
            simulation_folder = file_path,
        )
        build!(sim_cache)
        execute!(sim_cache)
        var_names =
            axes(PSI.get_stage(sim_cache, "UC").internal.psi_container.variables[:On__ThermalStandard])[1]
        for name in var_names
            var =
                PSI.get_stage(sim_cache, "UC").internal.psi_container.variables[:On__ThermalStandard][
                    name,
                    24,
                ]
            cache = collect(values(sim_cache.internal.simulation_cache))[1].value[name]
            @test JuMP.value(var) == cache[:status]
        end
    end

end
try
    test_load_simulation(path)
finally
    @info("removing test files")
    rm(path, recursive = true)
end

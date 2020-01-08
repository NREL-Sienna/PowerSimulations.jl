IS.configure_logging(console_level = Logging.Info)
if !isdir(joinpath(pwd(), "testing_reading_results"))
    file_path = mkdir(joinpath(pwd(), "testing_reading_results"))
else
    file_path = joinpath(pwd(), "testing_reading_results")
end

function test_chronology(file_path::String)    
    ### Receding Horizon

    stages_definition = Dict("UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
                               "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer))

    sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 1, to_executions = 1)),
                horizons = Dict("UC" => 24, "ED" =>12),
                intervals = Dict("UC" => Hour(1), "ED" => Minute(5)),
                feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P]),
                                    ("ED", :devices, :HydED1) => PSI.IntegralLimitFF(variable_from_stage = :P,affected_variables = [:P])),
                cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                ini_cond_chronology = Dict("UC" => RecedingHorizon(), "ED" => RecedingHorizon())
                )

    sim = Simulation(name = "receding",
                    steps = 2, step_resolution =Hour(1),
                    stages = stages_definition,
                    stages_sequence = sequence,
                    simulation_folder= file_path,
                    verbose = true)
                    
    build!(sim)
    sim_results = execute!(sim)
    results = load_simulation_results(sim_results, "UC")

    @testset "Testing to verify time gap for Receding Horizon" begin
        names = ["UC"] # TODO why doesn't this work for ED??
        for name in names
            variable_list = PSI.get_variable_names(sim, name)
            reference_1 = PSI.get_reference(sim_results, name, 1, variable_list[1])[1]
            reference_2 = PSI.get_reference(sim_results, name, 2, variable_list[1])[1]
            time_file_path_1 = joinpath(dirname(reference_1), "time_stamp.feather") #first line, file path
            time_file_path_2 = joinpath(dirname(reference_2), "time_stamp.feather")
            time_1 = convert(Dates.DateTime, Feather.read(time_file_path_1)[1,1]) # first time
            time_2 = convert(Dates.DateTime, Feather.read(time_file_path_2)[1,1])
            time_change = time_2 - time_1
            interval = PSI.get_interval(PSI.get_sequence(sim),name)
            @test Dates.Hour(time_change) == Dates.Hour(interval)
        end
    end

    @testset "Testing to verify parameter feedforward for Receding Horizon" begin
        P_keys = [PowerSimulations.UpdateRef{VariableRef}(:ON_ThermalStandard)]
        vars_names = [:ON_ThermalStandard]
        for (ik, key) in enumerate(P_keys)
            variable_ref = PSI.get_reference(sim_results, "UC", 1, vars_names[ik])[1]
            raw_result = Feather.read(variable_ref)
            ic = collect(values(value.(sim.stages["ED"].internal.psi_container.parameters[key])).data)
            for i in 1:size(ic, 1)
                result = raw_result[1, i] # first time period of results  [time, device]
                initial = ic[i, 1] # [device, time]
                @test isapprox(initial, result)
            end
        end
    end

    @testset "Testing to verify initial condition feedforward for Receding Horizon" begin
        results = load_simulation_results(sim_results, "ED")
        ic_keys = [PSI.ICKey(PSI.DevicePower, PSY.ThermalStandard)]
        vars_names = [:P_ThermalStandard]
        for (ik, key) in enumerate(ic_keys)
            initial_conditions = get_initial_conditions(PSI.get_psi_container(sim, "UC"), key)
            vars = results.variables[vars_names[ik]] # change to getter function
            for ic in initial_conditions 
                output = vars[1,Symbol(PSI.device_name(ic))] # change to getter function
                initial_cond = value(PSI.get_condition(ic))
                @test isapprox(output, initial_cond, atol = 1e-4)
            end
        end
    end

    ### Consecutive
    stages_definition = Dict("UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
                               "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer))

    sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 24, to_executions = 1)),
                horizons = Dict("UC" => 24, "ED" => 12),
                intervals = Dict("UC" => Hour(24), "ED" => Hour(1)),
                feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                )

    sim = Simulation(name = "consecutive",
                steps = 2, step_resolution = Hour(24),
                stages = stages_definition,
                stages_sequence = sequence,
                simulation_folder= file_path,
                verbose = true)
    build!(sim)

    sim_results = execute!(sim)
    
    @testset "Testing to verify time gap for Consecutive" begin
        names = ["UC"] # stage TODO why doesn't this work for ED??
        for name in names
            variable_list = PSI.get_variable_names(sim, name)
            reference_1 = PSI.get_reference(sim_results, name, 1, variable_list[1])[1]
            reference_2 = PSI.get_reference(sim_results, name, 2, variable_list[1])[1]
            time_file_path_1 = joinpath(dirname(reference_1), "time_stamp.feather") #first line, file path
            time_file_path_2 = joinpath(dirname(reference_2), "time_stamp.feather")
            time_1 = convert(Dates.DateTime, Feather.read(time_file_path_1)[end,1]) # first time
            time_2 = convert(Dates.DateTime, Feather.read(time_file_path_2)[1,1])
            @test time_2 == time_1
        end
    end

    @testset "Testing to verify initial condition feedforward for consecutive ED to UC" begin
        ic_keys = [PSI.ICKey(PSI.DevicePower, PSY.ThermalStandard)]
        vars_names = [:P_ThermalStandard]
        for (ik,key) in enumerate(ic_keys)
            variable_ref = PSI.get_reference(sim_results, "ED", 1, vars_names[ik])[24]
            initial_conditions = get_initial_conditions(PSI.get_psi_container(sim, "UC"), key)
            for ic in initial_conditions 
                raw_result = Feather.read(variable_ref)[end,Symbol(PSI.device_name(ic))] # last value of last hour
                initial_cond = value(PSI.get_condition(ic))
                @test isapprox(raw_result, initial_cond)
            end
        end
    end

    sim = Simulation(name = "consecutive",
                steps = 1, step_resolution = Hour(24),
                stages = stages_definition,
                stages_sequence = sequence,
                simulation_folder= file_path,
                verbose = true)
    build!(sim)

    sim_results = execute!(sim)
    @testset "Testing to verify parameter feedforward for consecutive UC to ED" begin
        P_keys = [PSI.UpdateRef{VariableRef}(:ON_ThermalStandard), PSI.UpdateRef{VariableRef}(:P_HydroDispatch)]
        vars_names = [:ON_ThermalStandard, :P_HydroDispatch]
        for (ik, key) in enumerate(P_keys)
            variable_ref = PSI.get_reference(sim_results, "UC", 1, vars_names[ik])[1] # 1 is first step
            ic = collect(values(value.(sim.stages["ED"].internal.psi_container.parameters[key])).data)# [device, time] 1 is first execution
            raw_result = Feather.read(variable_ref)
            for i in 1:size(ic,1)
                result = raw_result[end,i] # end is last result [time, device]
                initial = ic[i,1] # [device, time]
                @test isapprox(initial, result)
            end
        end
    end

    ### Synchronize

    ### Testing chronology of aggregation for Synchronize

    @testset "Testing to verify length of time_stamp" begin
        for name in keys(sim.stages)
            results = load_simulation_results(sim_results, name)
            @test size(unique(results.time_stamp), 1) == size(results.time_stamp, 1)
        end
    end

    @testset "Testing to verify no gaps in the time_stamp" begin
        for name in keys(sim.stages)
            stage = sim.stages[name]
            results = load_simulation_results(sim_results, name)
            resolution = convert(Dates.Millisecond, PSY.get_forecasts_resolution(PSI.get_sys(stage)))
            time_stamp = results.time_stamp
            length = size(time_stamp,1)
            test = results.time_stamp[1,1]:resolution:results.time_stamp[length,1]
            @test time_stamp[!,:Range] == test
        end
    end
end
try
    test_chronology(file_path)
finally
    @info("removing test files")
    rm(file_path, recursive=true)
end

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
                horizons = Dict("UC" => 24, "ED" =>12),
                intervals = Dict("UC" => Hour(24), "ED" => Hour(1)),
                feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                ini_cond_chronology = Dict("UC" => RecedingHorizon(), "ED" => RecedingHorizon())
                )

    sim = Simulation(name = "receding",
                    steps = 2,
                    step_resolution = Hour(24),
                    stages = stages_definition,
                    stages_sequence = sequence,
                    simulation_folder= file_path,
                    verbose = true)
    build!(sim)
    sim_results = execute!(sim)
    results = load_simulation_results(sim_results, "UC")

    @testset "Testing to verify time gap for Receding Horizon" begin
        name = "UC" # stage
        variable_list = get_variable_names(sim, name)
        reference_1 = get_reference(sim_results, name, 1, variable_list[1])[1]
        reference_2 = get_reference(sim_results, name, 2, variable_list[1])[1]
        time_file_path_1 = joinpath(dirname(reference_1), "time_stamp.feather") #first line, file path
        time_file_path_2 = joinpath(dirname(reference_2), "time_stamp.feather")
        time_1 = convert(Dates.DateTime, Feather.read(time_file_path_1)[1,1]) # first time
        time_2 = convert(Dates.DateTime, Feather.read(time_file_path_2)[1,1])
        time_change = time_2 - time_1
        interval = sim.stages[name].interval # change to getter function
        @test Dates.Hour(time_change) == Dates.Hour(interval)
    end
# TODO move to load_sim
    @testset "Testing to verify initial condition feedforward for Receding Horizon" begin
        ic_keys = [PSI.ICKey(PSI.DevicePower, PSY.ThermalStandard),PSI.ICKey(PSI.DeviceStatus, PSY.ThermalStandard)]
        vars_names = [:P_ThermalStandard, :ON_ThermalStandard]
        for (ik, key) in enumerate(ic_keys)
            initial_conditions = get_initial_conditions(get_psi_container(sim, 1), key)
            vars = results.variables[vars_names[ik]] # change to getter function
            for ic in initial_conditions 
                output = vars[end-1,Symbol(PSI.device_name(ic))] # change to getter function
                initial_cond = value(PSI.get_condition(ic))
                @test isapprox(output, initial_cond, atol = 1e-4)
            end
        end
    end

    ### Consecutive
    stages_definition = Dict("UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
                               "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer))

        sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                   intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 1, to_executions = 1)),
                   horizons = Dict("UC" => 24, "ED" => 12),
                   intervals = Dict("UC" => Hour(24), "ED" => Hour(1)),
                   feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                   cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                   ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                   )

        sim = Simulation(name = "consecutive",
                 steps = 3,
                 step_resolution = Hour(24),
                 stages = stages_definition,
                 stages_sequence = sequence,
                 simulation_folder= file_path,
                 verbose = true)
        build!(sim)

    sim_results = execute!(sim)
    
    @testset "Testing to verify time gap for Sequential" begin
        name = "UC" # stage
        variable_list = get_variable_names(sim, name)
        reference_1 = get_reference(sim_results, name, 1, variable_list[1])[1]
        reference_2 = get_reference(sim_results, name, 2, variable_list[1])[1]
        time_file_path_1 = joinpath(dirname(reference_1), "time_stamp.feather") #first line, file path
        time_file_path_2 = joinpath(dirname(reference_2), "time_stamp.feather")
        time_1 = convert(Dates.DateTime, Feather.read(time_file_path_1)[end,1]) # first time
        time_2 = convert(Dates.DateTime, Feather.read(time_file_path_2)[1,1])
        @test time_2 == time_1
    end

    @testset "Testing to verify initial condition feedforward for consecutive" begin
        ic_keys = [PSI.ICKey(PSI.DevicePower, PSY.ThermalStandard),PSI.ICKey(PSI.DeviceStatus, PSY.ThermalStandard)]
        vars_names = [:P_ThermalStandard, :ON_ThermalStandard]
        for (ik,key) in enumerate(ic_keys)
            variable_ref = get_reference(sim_results, 1, 2, vars_names[ik])[1]
            initial_conditions = get_initial_conditions(get_psi_container(sim, 1), key) # needs changed with update
            for ic in initial_conditions 
                raw_result = Feather.read(variable_ref)[end,Symbol(PSI.device_name(ic))] # change to getter function
                initial_cond = value(PSI.get_condition(ic))
                @test isapprox(raw_result, initial_cond, atol = 1e-4)
            end
        end
    end
    ### Synchronize
    @testset "Testing stage parameter feedforward for Synchronize" begin

        stages = Dict(1 => Stage(template_uc, 2, Dates.Hour(1), 1, c_sys5_uc, GLPK_optimizer,  Dict(0 => Sequential())),
            2 => Stage(template_ed, 12, Dates.Minute(5), 1, c_sys5_ed, GLPK_optimizer, 
            Dict(1 => Synchronize(1,1), 0 => Sequential()), TimeStatusChange(:ON_ThermalStandard)))
        sim = Simulation("feedforward", 1, stages, file_path)
        sim_results = execute!(sim)
        key = PowerSimulations.UpdateRef{JuMP.VariableRef}(:ON_ThermalStandard) # needs changed with update
        variable_ref = get_reference(sim_results, 1, 1, :ON_ThermalStandard)[1]
        for (count, i) in enumerate(get_psi_container(sim, 1).parameters[key]) # change to getter function
            raw_result = Feather.read(variable_ref)[1, count]
            @test raw_result == PJ.value(i)
        end
    end

    ### Testing chronology of aggregation for Synchronize
    stages = Dict(1 => Stage(template_uc, 24, Dates.Hour(24), 1, c_sys5_uc, GLPK_optimizer,  Dict(0 => Sequential())),
                2 => Stage(template_ed, 12, Dates.Minute(5), 24, c_sys5_ed, GLPK_optimizer, 
                Dict(1 => Synchronize(24,1), 0 => Sequential()), TimeStatusChange(:ON_ThermalStandard)))

    @testset "Testing to verify length of time_stamp" begin
    sim = Simulation("sync1", 2, stages, file_path; verbose = true)
    sim_results = execute!(sim)
        for name in keys(sim.stages)
            results = load_simulation_results(sim_results, name)
            @test size(unique(results.time_stamp), 1) == size(results.time_stamp, 1)
        end
    end

    @testset "Testing to verify no gaps in the time_stamp" begin
    sim = Simulation("sync2", 2, stages, file_path; verbose = true)
    sim_results = execute!(sim)
        for name in keys(sim.stages)
            stage = get_stage(sim, name)
            results = load_simulation_results(sim_results, name)
            resolution = convert(Dates.Minute, get_sim_resolution(stage))
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
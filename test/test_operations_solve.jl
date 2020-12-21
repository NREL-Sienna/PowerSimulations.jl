devices = Dict{Symbol, DeviceModel}(
    :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
)
branches = Dict{Symbol, DeviceModel}(
    :L => DeviceModel(Line, StaticLine),
    :T => DeviceModel(Transformer2W, StaticTransformer),
    :TT => DeviceModel(TapTransformer, StaticTransformer),
)
services = Dict{Symbol, ServiceModel}()

@testset "Solving ED with CopperPlate" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    parameters_value = [true, false]
    c_sys5 = build_system("c_sys5")
    c_sys14 = build_system("c_sys14")
    systems = [c_sys5, c_sys14]
    test_results = Dict{System, Float64}(c_sys5 => 240000.0, c_sys14 => 142000.0)
    @info "Test solve ED with CopperPlatePowerModel network"
    for sys in systems, p in parameters_value
        @testset "ED CopperPlatePowerModel model use_parameters = $(p)" begin
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = OSQP_optimizer,
                use_parameters = p,
            )
            psi_checksolve_test(ED, [MOI.OPTIMAL], test_results[sys], 10000)
        end
    end
    c_sys5_re = build_system("c_sys5_re")
    ED = OperationsProblem(
        TestOpProblem,
        template,
        c_sys5_re;
        optimizer = GLPK_optimizer,
        balance_slack_variables = true,
    )
    psi_checksolve_test(ED, [MOI.OPTIMAL], 240000.0, 10000)
end

@testset "Solving ED with PTDF Models" begin
    template = OperationsProblemTemplate(StandardPTDFModel, devices, branches, services)
    parameters_value = [true, false]
    c_sys5 = build_system("c_sys5")
    c_sys14 = build_system("c_sys14")
    c_sys14_dc = build_system("c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => build_PTDF5(),
        c_sys14 => build_PTDF14(),
        c_sys14_dc => build_PTDF14_dc(),
    )
    test_results = IdDict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )

    @info "Test solve ED with StandardPTDFModel network"
    for sys in systems, p in parameters_value
        @testset "ED StandardPTDFModel model use_parameters = $(p)" begin
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = OSQP_optimizer,
                use_parameters = p,
                PTDF = PTDF_ref[sys],
            )
            psi_checksolve_test(ED, [MOI.OPTIMAL], test_results[sys], 10000)
        end
    end
end

@testset "Solving ED With PowerModels with loss-less convex models" begin
    c_sys5 = build_system("c_sys5")
    c_sys14 = build_system("c_sys14")
    c_sys14_dc = build_system("c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters_value = [true, false]
    networks = [DCPPowerModel, NFAPowerModel]
    test_results = Dict{System, Float64}(
        c_sys5 => 330000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )

    for net in networks, p in parameters_value, sys in systems
        @info("Test solve ED with $(net) network")
        @testset "ED model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net, devices, branches, services)
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
                use_parameters = p,
            )
            #The tolerance range here is large because NFA has a much lower objective value
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[sys],
                35000,
            )
        end
    end
end

@testset "Solving ED With PowerModels with linear convex models" begin
    c_sys5 = build_system("c_sys5")
    c_sys14 = build_system("c_sys14")
    c_sys14_dc = build_system("c_sys14_dc")
    systems = [c_sys5, c_sys14]
    parameters_value = [true, false]
    networks = [DCPLLPowerModel, LPACCPowerModel]
    test_results = IdDict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )

    for net in networks, p in parameters_value, sys in systems
        @info("Test solve ED with $(net) network")
        @testset "ED model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net, devices, branches, services)
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
                use_parameters = p,
            )
            #The tolerance range here is large because NFA has a much lower objective value
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[sys],
                10000,
            )
        end
    end
end

@testset "Operation Model Constructors with Slacks" begin
    networks = [StandardPTDFModel, DCPPowerModel, ACPPowerModel]

    thermal_gens = [ThermalDispatch]

    c_sys5_re = build_system("c_sys5_re")
    systems = [c_sys5_re]
    for net in networks, thermal in thermal_gens, system in systems
        devices = Dict{Symbol, DeviceModel}(
            :Generators => DeviceModel(ThermalStandard, thermal),
            :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
            :RE => DeviceModel(RenewableDispatch, FixedOutput),
        )
        branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(Line, StaticLine))
        template = OperationsProblemTemplate(net, devices, branches, services)
        op_problem = OperationsProblem(
            TestOpProblem,
            template,
            system;
            balance_slack_variables = true,
            optimizer = ipopt_optimizer,
            PTDF = build_PTDF5(),
        )
        res = solve!(op_problem)
        @test termination_status(op_problem.psi_container.JuMPmodel) in
              [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
    end
end
#=
@testset "Solving ED With PowerModels with convex SOC and QC models" begin
    systems = [c_sys5, c_sys14]
    parameters_value = [true, false]
    networks = [SOCWRPowerModel,
                 QCRMPowerModel,
                 QCLSPowerModel,]
    test_results = Dict{System, Float64}(c_sys5 => 320000.0,
                                             c_sys14 => 142000.0)
    for  net in networks, p in parameters_value, sys in systems
        @info("Test solve ED with $(net) network")
        @testset "ED model $(net) and use_parameters = $(p)" begin
        template = OperationsProblemTemplate(net, devices, branches, services);
        ED = OperationsProblem(TestOpProblem, template, sys; optimizer = ipopt_optimizer, use_parameters = p);
        #The tolerance range here is large because Relaxations have a lower objective value
        psi_checksolve_test(ED, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], test_results[sys], 25000)
        end
    end
end
=#

@testset "Solving ED With PowerModels Non-Convex Networks" begin
    c_sys5 = build_system("c_sys5")
    c_sys14 = build_system("c_sys14")
    c_sys14_dc = build_system("c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    parameters_value = [true, false]
    networks = [
        ACPPowerModel,
        #ACRPowerModel,
        ACTPowerModel,
    ]
    test_results = Dict{System, Float64}(
        c_sys5 => 340000.0,
        c_sys14 => 142000.0,
        c_sys14_dc => 142000.0,
    )

    for net in networks, p in parameters_value, sys in systems
        @info("Test solve ED with $(net) network")
        @testset "ED model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net, devices, branches, services)
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
                use_parameters = p,
            )
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[sys],
                10000,
            )
        end
    end
end

@testset "Solving ED Hydro System using Dispatch Run of River" begin
    sys = build_system("c_sys5_hy")
    parameters_value = [true, false]
    networks = [ACPPowerModel, DCPPowerModel]

    test_results = Dict{Any, Float64}(ACPPowerModel => 12414.0, DCPPowerModel => 12218.0)

    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
        :HydroGens => DeviceModel(HydroDispatch, HydroDispatchRunOfRiver),
    )

    for net in networks, p in parameters_value
        @info("Test solve HydroRoR ED with $(net) network")
        @testset "HydroRoR ED model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net, devices, branches, services)
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
                use_parameters = p,
            )
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[net],
                1000,
            )
        end
    end
end

@testset "Solving ED Hydro System using Commitment Run of River" begin
    sys = build_system("c_sys5_hy")
    parameters_value = [true, false]
    net = DCPPowerModel

    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
        :HydroGens => DeviceModel(HydroDispatch, HydroCommitmentRunOfRiver),
    )

    for p in parameters_value
        @info("Test solve HydroRoR ED with $(net) network")
        @testset "HydroRoR ED model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net, devices, branches, services)
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = GLPK_optimizer,
                use_parameters = p,
            )
            psi_checksolve_test(ED, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], 12218.0, 1000)
        end
    end
end

@testset "Solving ED Hydro System using Dispatch with Reservoir" begin
    sys = build_system("c_sys5_hyd")
    parameters_value = [true, false]
    networks = [ACPPowerModel, DCPPowerModel]
    models = [HydroDispatchReservoirBudget, HydroDispatchReservoirStorage]
    test_results = Dict{Any, Float64}(
        (ACPPowerModel, HydroDispatchReservoirBudget) => 338977.0,
        (DCPPowerModel, HydroDispatchReservoirBudget) => 337646.0,
        (ACPPowerModel, HydroDispatchReservoirStorage) => 303157.0,
        (DCPPowerModel, HydroDispatchReservoirStorage) => 301826.0,
    )
    parameters_value = [true, false]

    for net in networks, mod in models, p in parameters_value
        @info("Test solve HydroRoR ED with $(net) network")
        @testset "$(mod) ED model on $(net) and use_parameters = $(p)" begin
            devices = Dict{Symbol, DeviceModel}(
                :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
                :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
                :HydroGens => DeviceModel(HydroEnergyReservoir, mod),
            )
            template = OperationsProblemTemplate(net, devices, branches, services)
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = ipopt_optimizer,
                use_parameters = p,
            )
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[(net, mod)],
                10000,
            )
        end
    end
end

@testset "Solving ED Hydro System using Commitment with Reservoir" begin
    sys = build_system("c_sys5_hyd")
    parameters_value = [true, false]
    net = DCPPowerModel
    models = [HydroCommitmentReservoirBudget, HydroCommitmentReservoirStorage]
    test_results = Dict{Any, Float64}(
        HydroCommitmentReservoirBudget => 337646.0,
        HydroCommitmentReservoirStorage => 301826.0,
    )

    for mod in models, p in parameters_value
        @info("Test solve HydroRoR ED with $(net) network")
        @testset "$(mod) ED model on $(net) and use_parameters = $(p)" begin
            devices = Dict{Symbol, DeviceModel}(
                :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
                :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
                :HydroGens => DeviceModel(HydroEnergyReservoir, mod),
            )
            template = OperationsProblemTemplate(net, devices, branches, services)
            ED = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = GLPK_optimizer,
                use_parameters = p,
            )
            psi_checksolve_test(
                ED,
                [MOI.OPTIMAL, MOI.LOCALLY_SOLVED],
                test_results[mod],
                10000,
            )
        end
    end
end

@testset "Solving UC Linear Networks" begin
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    )
    c_sys5 = build_system("c_sys5")
    c_sys5_dc = build_system("c_sys5_dc")
    parameters_value = [true, false]
    systems = [c_sys5, c_sys5_dc]
    networks = [DCPPowerModel, NFAPowerModel, StandardPTDFModel, CopperPlatePowerModel]
    PTDF_ref = IdDict{System, PTDF}(c_sys5 => build_PTDF5(), c_sys5_dc => build_PTDF5_dc())

    for net in networks, p in parameters_value, sys in systems
        @info("Test solve UC with $(net) network")
        @testset "UC model $(net) and use_parameters = $(p)" begin
            template = OperationsProblemTemplate(net, devices, branches, services)
            UC = OperationsProblem(
                TestOpProblem,
                template,
                sys;
                optimizer = GLPK_optimizer,
                use_parameters = p,
                PTDF = PTDF_ref[sys],
            )
            psi_checksolve_test(UC, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], 340000, 100000)
        end
    end
end

@testset "Set optimizer at solve call" begin
    c_sys5 = build_system("c_sys5")
    devices = Dict{Symbol, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    )
    template = OperationsProblemTemplate(DCPPowerModel, devices, branches, services)
    UC = OperationsProblem(TestOpProblem, template, c_sys5;)
    set_services_template!(
        UC,
        Dict(:Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve)),
    )
    res = solve!(UC; optimizer = GLPK_optimizer)
    @test isapprox(get_total_cost(res)[:OBJECTIVE_FUNCTION], 340000.0; atol = 100000.0)
end

@testset "Test duals and variables getter functions" begin
    duals = [:CopperPlateBalance]
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    c_sys5_re = build_system("c_sys5_re")
    op_problem = OperationsProblem(
        TestOpProblem,
        template,
        c_sys5_re;
        optimizer = OSQP_optimizer,
        use_parameters = true,
        constraint_duals = duals,
    )
    res = solve!(op_problem)

    @testset "test constraint duals in the operations problem" begin
        name = PSI.make_constraint_name("CopperPlateBalance")
        for i in 1:ncol(IS.get_timestamp(res))
            dual = JuMP.dual(op_problem.psi_container.constraints[name][i])
            @test isapprox(dual, PSI.get_duals(res)[name][i, 1])
        end
        dual_results = get_dual_values(op_problem.psi_container, duals)
        @test dual_results == res.dual_values
    end

    @testset "Test parameter values" begin
        system = op_problem.sys
        params =
            PSI.get_parameter_array(op_problem.psi_container.parameters[:P__max_active_power__PowerLoad])
        params = PSI.axis_array_to_dataframe(params)
        devices = collect(PSY.get_components(PSY.PowerLoad, c_sys5_re))
        multiplier = [PSY.get_active_power(devices[1])]
        for d in 2:length(devices)
            multiplier = hcat(multiplier, PSY.get_active_power(devices[d]))
        end
        extracted = -multiplier .* params
        @test extracted == res.parameter_values[:P_PowerLoad]
    end
end

function test_op_problem_write_functions(file_path)
    duals = [:CopperPlateBalance]
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    c_sys5_re = build_system("c_sys5_re")
    op_problem = OperationsProblem(
        TestOpProblem,
        template,
        c_sys5_re;
        optimizer = OSQP_optimizer,
        use_parameters = true,
        constraint_duals = duals,
    )
    res = solve!(op_problem)

    @testset "Test Serialization, deserialization and write optimizer problem" begin
        path = mkpath(joinpath(file_path, "op_problem"))
        file = joinpath(path, "op_problem.json")
        export_operations_model(op_problem, file)
        filename = joinpath(path, "test_op_problem.bin")
        serialize_problem(op_problem, filename)
        file_list = sort!(collect(readdir(path)))
        @test "op_problem.json" in file_list
        @test "test_op_problem.bin" in file_list
        ED2 = OperationsProblem(filename, optimizer = OSQP_optimizer)
        psi_checksolve_test(ED2, [MOI.OPTIMAL], 240000.0, 10000)
    end

    @testset "Test write_to_csv results functions" begin
        results_path = mkdir(joinpath(file_path, "results"))
        write_to_CSV(res, results_path)
        file_list = sort!(collect(readdir(results_path)))
    end
end

@testset "Operation write to disk functions" begin
    folder_path = mkpath(joinpath(pwd(), "test_writing"))
    try
        test_op_problem_write_functions(folder_path)
    finally
        @info("removing test files")
        rm(folder_path, recursive = true)
    end
end

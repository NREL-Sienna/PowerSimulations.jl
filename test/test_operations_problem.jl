test_path = mkpath(joinpath(mktempdir(cleanup = true), "test_operations_problem"))
#TODO: Make more tests with Settings
@testset "Operation Model kwargs" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")

    @test_throws MethodError OperationsProblem(template, c_sys5; bad_kwarg = 10)

    test_folder = mkpath(joinpath(test_path, randstring()))
    op_problem = OperationsProblem(
        template,
        c_sys5;
        use_forecast_data = false,
        optimizer = GLPK_optimizer,
    )
    @test build!(op_problem; output_dir = test_folder) == PSI.BuildStatus.BUILT
    # TODO: there is an inconsistency because Horizon isn't 1
    @test PSI.get_use_forecast_data(
        PSI.get_settings(PSI.get_optimization_container(op_problem)),
    ) == false

    op_problem = OperationsProblem(
        MockOperationProblem,
        template,
        c_sys5_re;
        optimizer = GLPK_optimizer,
        balance_slack_variables = true,
    )

    test_folder = mkpath(joinpath(test_path, randstring()))
    op_problem = OperationsProblem(
        template,
        c_sys5;
        use_forecast_data = false,
        optimizer = GLPK_optimizer,
    )
    @test build!(op_problem; output_dir = test_folder) == PSI.BuildStatus.BUILT
    # TODO: there is an inconsistency because Horizon isn't 1
    @test PSI.get_use_forecast_data(
        PSI.get_settings(PSI.get_optimization_container(op_problem)),
    ) == false

    #"Test passing custom JuMP model"
    my_model = JuMP.Model()
    my_model.ext[:PSI_Testing] = 1
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem = OperationsProblem(
        MockOperationProblem,
        template,
        c_sys5,
        my_model;
        optimizer = GLPK_optimizer,
        use_parameters = true,
    )
    @test haskey(op_problem.optimization_container.JuMPmodel.ext, :PSI_Testing)
    @test (:params in keys(op_problem.optimization_container.JuMPmodel.ext)) == true
end

@testset "Set optimizer at solve call" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    devices = Dict{String, DeviceModel}(
        :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
        :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    )
    template = OperationsProblemTemplate(DCPPowerModel, devices, branches, services)
    UC = OperationsProblem(MockOperationProblem, template, c_sys5;)
    set_services_template!(
        UC,
        Dict(:Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve)),
    )
    res = solve!(UC; optimizer = GLPK_optimizer)
    @test isapprox(get_total_cost(res)[:OBJECTIVE_FUNCTION], 340000.0; atol = 100000.0)
end

@testset "Test optimization debugging functions" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem = OperationsProblem(
        MockOperationProblem,
        template,
        c_sys5;
        optimizer = GLPK_optimizer,
        use_parameters = true,
    )
    MOIU.attach_optimizer(op_problem.optimization_container.JuMPmodel)
    constraint_indices = get_all_constraint_index(op_problem)
    for (key, index, moi_index) in constraint_indices
        val1 = get_con_index(op_problem, moi_index)
        val2 = op_problem.optimization_container.constraints[key].data[index]
        @test val1 == val2
    end
    @test isnothing(get_con_index(op_problem, length(constraint_indices) + 1))

    var_indices = get_all_var_index(op_problem)
    for (key, index, moi_index) in var_indices
        val1 = get_var_index(op_problem, moi_index)
        val2 = op_problem.optimization_container.variables[key].data[index]
        @test val1 == val2
    end
    @test isnothing(get_var_index(op_problem, length(var_indices) + 1))
end

@testset "Test print methods" begin
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem = OperationsProblem(
        MockOperationProblem,
        template,
        c_sys5;
        optimizer = GLPK_optimizer,
        use_parameters = true,
    )
    list = [template, op_problem, op_problem.optimization_container, services]
    _test_plain_print_methods(list)
    list = [services]
    _test_html_print_methods(list)
end

@testset "Operation Model Solve with Slacks" begin
    networks = [StandardPTDFModel, DCPPowerModel, ACPPowerModel]

    thermal_gens = [ThermalDispatch]

    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    systems = [c_sys5_re]
    for net in networks, thermal in thermal_gens, system in systems
        devices = Dict{String, DeviceModel}(
            :Generators => DeviceModel(ThermalStandard, thermal),
            :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
            :RE => DeviceModel(RenewableDispatch, FixedOutput),
        )
        branches = Dict{String, DeviceModel}(:L => DeviceModel(Line, StaticLine))
        template = OperationsProblemTemplate(net, devices, branches, services)
        op_problem = OperationsProblem(
            MockOperationProblem,
            template,
            system;
            balance_slack_variables = true,
            optimizer = ipopt_optimizer,
            PTDF = PTDF(c_sys5_re),
        )
        res = solve!(op_problem)
        @test termination_status(op_problem.optimization_container.JuMPmodel) in
              [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
    end
end

@testset "Operations constructors" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem_ed = PSI.EconomicDispatchProblem(c_sys5)
    op_problem_uc = PSI.UnitCommitmentProblem(c_sys5)
    moi_tests(op_problem_uc, false, 480, 0, 240, 120, 144, true)
    moi_tests(op_problem_ed, false, 120, 0, 168, 120, 24, false)
    ED = PSI.run_economic_dispatch(c_sys5; optimizer = fast_lp_optimizer)
    UC = PSI.run_unit_commitment(c_sys5; optimizer = fast_lp_optimizer)
    @test ED.optimizer_log[:primal_status] == MOI.FEASIBLE_POINT
    @test UC.optimizer_log[:primal_status] == MOI.FEASIBLE_POINT
end

@testset "Test duals and variables getter functions" begin
    duals = [:CopperPlateBalance]
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    op_problem = OperationsProblem(
        MockOperationProblem,
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
            dual = JuMP.dual(op_problem.optimization_container.constraints[name][i])
            @test isapprox(dual, PSI.get_duals(res)[name][i, 1])
        end
        dual_results = read_duals(op_problem.optimization_container, duals)
        @test dual_results == res.dual_values
    end

    @testset "Test parameter values" begin
        system = op_problem.sys
        params = PSI.get_parameter_array(
            op_problem.optimization_container.parameters[:P__max_active_power__PowerLoad],
        )
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
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    op_problem = OperationsProblem(
        MockOperationProblem,
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
        serialize_model(op_problem, filename)
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

@testset "Test Locational Marginal Prices between DC lossless with PowerModels vs StandardPTDFModel" begin
    network = [DCPPowerModel, StandardPTDFModel]
    sys = PSB.build_system(PSITestSystems, "c_sys5")
    dual_constraint = [[:nodal_balance_active__Bus], [:CopperPlateBalance, :network_flow]]
    services = Dict{String, ServiceModel}()
    devices = Dict(:Thermal => thermal_model, :Load => load_model)
    branches = Dict{String, DeviceModel}(
        :Line => line_model,
        :Tf => transformer_model,
        :Ttf => ttransformer_model,
        :DCLine => dc_line,
    )
    parameters = [true, false]
    ptdf = PTDF(sys)
    LMPs = []
    for (ix, net) in enumerate(network), p in parameters
        template = OperationsProblemTemplate(net, devices, branches, services)
        ps_model = OperationsProblem(
            MockOperationProblem,
            template,
            sys;
            optimizer = OSQP_optimizer,
            use_parameters = p,
            PTDF = ptdf,
            constraint_duals = dual_constraint[ix],
        )

        if net == StandardPTDFModel
            push!(LMPs, abs.(psi_ptdf_lmps(ps_model, ptdf)))
        else
            res = solve!(ps_model)
            duals = abs.(res.dual_values[:nodal_balance_active__Bus])
            push!(LMPs, duals[!, sort(propertynames(duals))])
        end
    end
    @test isapprox(convert(Array, LMPs[1]), convert(Array, LMPs[2]), atol = 100.0)
end

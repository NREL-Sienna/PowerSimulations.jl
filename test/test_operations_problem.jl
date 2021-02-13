# TODO: Make more tests with Settings
@testset "Operation Model kwargs" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")

    @test_throws MethodError OperationsProblem(template, c_sys5; bad_kwarg = 10)

    op_problem = OperationsProblem(
        template,
        c_sys5;
        use_forecast_data = false,
        optimizer = GLPK_optimizer,
    )
    @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT
    @test PSI.get_use_forecast_data(
        PSI.get_settings(PSI.get_optimization_container(op_problem)),
    ) == false

    op_problem = OperationsProblem(
        MockOperationProblem,
        get_thermal_dispatch_template_network(),
        c_sys5_re;
        optimizer = GLPK_optimizer,
        balance_slack_variables = true,
    )
    op_problem = OperationsProblem(
        get_thermal_dispatch_template_network(),
        c_sys5;
        use_forecast_data = false,
        optimizer = GLPK_optimizer,
    )
    @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT
    @test PSI.get_use_forecast_data(
        PSI.get_settings(PSI.get_optimization_container(op_problem)),
    ) == false

    #"Test passing custom JuMP model"
    my_model = JuMP.Model()
    my_model.ext[:PSI_Testing] = 1
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem = OperationsProblem(
        get_thermal_dispatch_template_network(),
        c_sys5,
        my_model;
        optimizer = GLPK_optimizer,
        use_parameters = true,
    )
    build!(op_problem; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    @test haskey(PSI.get_optimization_container(op_problem).JuMPmodel.ext, :PSI_Testing)
    @test (:params in keys(PSI.get_optimization_container(op_problem).JuMPmodel.ext)) ==
          true
end

@testset "Set optimizer at solve call" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    template = get_thermal_standard_uc_template()
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    UC = OperationsProblem(template, c_sys5)
    @test build!(UC; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    @test solve!(UC; optimizer = GLPK_optimizer) == RunStatus.SUCCESSFUL
    # Test Disable because needs operations results
    # @test isapprox(get_total_cost(res)[:OBJECTIVE_FUNCTION], 340000.0; atol = 100000.0)
end

@testset "Test optimization debugging functions" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    template = get_thermal_standard_uc_template()
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    op_problem = OperationsProblem(template, c_sys5; optimizer = GLPK_optimizer)
    @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT
    optimization_container = PSI.get_optimization_container(op_problem)
    MOIU.attach_optimizer(optimization_container.JuMPmodel)
    constraint_indices = get_all_constraint_index(op_problem)
    for (key, index, moi_index) in constraint_indices
        val1 = get_con_index(op_problem, moi_index)
        val2 = optimization_container.constraints[key].data[index]
        @test val1 == val2
    end
    @test isnothing(get_con_index(op_problem, length(constraint_indices) + 1))

    var_indices = get_all_var_index(op_problem)
    for (key, index, moi_index) in var_indices
        val1 = get_var_index(op_problem, moi_index)
        val2 = optimization_container.variables[key].data[index]
        @test val1 == val2
    end
    @test isnothing(get_var_index(op_problem, length(var_indices) + 1))
end

# @testset "Test print methods" begin
#     template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
#     c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
#     op_problem = OperationsProblem(
#         MockOperationProblem,
#         template,
#         c_sys5;
#         optimizer = GLPK_optimizer,
#         use_parameters = true,
#     )
#     list = [template, op_problem, op_problem.optimization_container, services]
#     _test_plain_print_methods(list)
#     list = [services]
#     _test_html_print_methods(list)
# end

@testset "Operation Model Solve with Slacks" begin
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    networks = [StandardPTDFModel, DCPPowerModel, ACPPowerModel]
    for network in networks
        template = get_thermal_dispatch_template_network(network)
        op_problem = OperationsProblem(
            template,
            c_sys5_re;
            balance_slack_variables = true,
            optimizer = ipopt_optimizer,
            PTDF = PTDF(c_sys5_re),
        )
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        @test solve!(op_problem) == RunStatus.SUCCESSFUL
    end
end

@testset "Default Operations Constructors" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    op_problem_ed = EconomicDispatchProblem(c_sys5; output_dir = mktempdir())
    moi_tests(op_problem_ed, false, 120, 0, 120, 120, 24, false)
    op_problem_uc = UnitCommitmentProblem(c_sys5; output_dir = mktempdir())
    moi_tests(op_problem_uc, false, 480, 0, 240, 120, 144, true)
    ED_output = run_economic_dispatch(
        c_sys5;
        output_dir = mktempdir(),
        optimizer = fast_lp_optimizer,
    )
    UC_output =
        run_unit_commitment(c_sys5; output_dir = mktempdir(), optimizer = fast_lp_optimizer)
    @test ED_output == RunStatus.SUCCESSFUL
    @test UC_output == RunStatus.SUCCESSFUL
end

@testset "Test Locational Marginal Prices between DC lossless with PowerModels vs StandardPTDFModel" begin
    networks = [DCPPowerModel, StandardPTDFModel]
    sys = PSB.build_system(PSITestSystems, "c_sys5")
    parameters = [true, false]
    ptdf = PTDF(sys)
    # These are the duals of interest for the test
    dual_constraint = [[:nodal_balance_active__Bus], [:CopperPlateBalance, :network_flow]]
    LMPs = []
    for (ix, network) in enumerate(networks), p in parameters
        template = get_template_dispatch_with_network(network)
        op_problem = OperationsProblem(
            template,
            sys;
            optimizer = OSQP_optimizer,
            use_parameters = p,
            PTDF = ptdf,
            constraint_duals = dual_constraint[ix],
        )
        @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
              PSI.BuildStatus.BUILT
        @test solve!(op_problem) == RunStatus.SUCCESSFUL

        # These tests require results to be working
        #if net == StandardPTDFModel
        #    push!(LMPs, abs.(psi_ptdf_lmps(ps_model, ptdf)))
        #else
        #    res = solve!(ps_model)
        #    duals = abs.(res.dual_values[:nodal_balance_active__Bus])
        #    push!(LMPs, duals[!, sort(propertynames(duals))])
        #end
    end
    #@test isapprox(convert(Array, LMPs[1]), convert(Array, LMPs[2]), atol = 100.0)
end

@testset "Test duals and parameters getter functions" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_re")
    template = get_template_dispatch_with_network(CopperPlatePowerModel)
    op_problem = OperationsProblem(
        template,
        sys;
        optimizer = OSQP_optimizer,
        use_parameters = true,
        constraint_duals = [:CopperPlateBalance],
    )
    @test build!(op_problem; output_dir = mktempdir(cleanup = true)) ==
          PSI.BuildStatus.BUILT
    @test solve!(op_problem) == RunStatus.SUCCESSFUL

    optimization_container = PSI.get_optimization_container(op_problem)
    constraints = PSI.get_constraints(optimization_container)[:CopperPlateBalance]
    dual_results = read_duals(optimization_container, [:CopperPlateBalance])
    for i in axes(constraints)[1]
        dual = JuMP.dual(constraints[i])
        @test isapprox(dual, dual_results[:CopperPlateBalance][i, 1])
    end

    system = PSI.get_system(op_problem)
    params = PSI.get_parameters(optimization_container)[:P__max_active_power__PowerLoad]
    param_vals = PSI.axis_array_to_dataframe(params.parameter_array)
    param_mult = PSI.axis_array_to_dataframe(params.multiplier_array)
    for load in get_components(PowerLoad, system)
        name = get_name(load)
        vals = get_time_series_values(Deterministic, load, "max_active_power")
        @test all([-1 * x == get_max_active_power(load) for x in param_mult[!, name]])
        @test all(vals .== param_vals[!, name])
    end
end

@testset "Test Serialization, deserialization and write optimizer problem" begin
    path = mktempdir(cleanup = true)
    sys = PSB.build_system(PSITestSystems, "c_sys5_re")
    template = get_template_dispatch_with_network(CopperPlatePowerModel)
    op_problem = OperationsProblem(
        template,
        sys;
        optimizer = OSQP_optimizer,
        use_parameters = true,
        constraint_duals = [:CopperPlateBalance],
    )
    @test build!(op_problem; output_dir = path) == PSI.BuildStatus.BUILT
    @test solve!(op_problem) == RunStatus.SUCCESSFUL

    file_list = sort!(collect(readdir(path)))
    @test "OptimizationModel.json" in file_list
    @test "OperationProblem.bin" in file_list
    filename = joinpath(path, "OperationProblem.bin")
    ED2 = OperationsProblem(filename, optimizer = OSQP_optimizer)
    build!(ED2, output_dir = path)
    psi_checksolve_test(ED2, [MOI.OPTIMAL], 240000.0, 10000)

    path2 = mktempdir(cleanup = true)
    op_problem_no_sys = OperationsProblem(
        template,
        sys;
        optimizer = OSQP_optimizer,
        use_parameters = true,
        system_to_file = false,
        constraint_duals = [:CopperPlateBalance],
    )

    @test build!(op_problem_no_sys; output_dir = path2) == PSI.BuildStatus.BUILT
    @test solve!(op_problem) == RunStatus.SUCCESSFUL

    file_list = sort!(collect(readdir(path2)))
    @test .!all(occursin.(r".h5", file_list))
    filename = joinpath(path2, "OperationProblem.bin")
    ED3 = OperationsProblem(filename; system = sys, optimizer = OSQP_optimizer)
    build!(ED3, output_dir = path2)
    psi_checksolve_test(ED3, [MOI.OPTIMAL], 240000.0, 10000)
end

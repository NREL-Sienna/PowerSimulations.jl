# TODO: Make more tests with Settings
@testset "Operation Model kwargs" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")

    @test_throws MethodError DecisionModel(template, c_sys5; bad_kwarg = 10)

    model = DecisionModel(
        template,
        c_sys5;
        use_forecast_data = false,
        optimizer = GLPK_optimizer,
    )
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT

    model = DecisionModel(
        MockOperationProblem,
        get_thermal_dispatch_template_network(),
        c_sys5_re;
        optimizer = GLPK_optimizer,
        balance_slack_variables = true,
    )
    model = DecisionModel(
        get_thermal_dispatch_template_network(),
        c_sys5;
        use_forecast_data = false,
        optimizer = GLPK_optimizer,
    )
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    e

    #"Test passing custom JuMP model"
    my_model = JuMP.Model()
    my_model.ext[:PSI_Testing] = 1
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(
        get_thermal_dispatch_template_network(),
        c_sys5,
        my_model;
        optimizer = GLPK_optimizer,
    )
    build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    @test haskey(PSI.get_optimization_container(model).JuMPmodel.ext, :PSI_Testing)
    @test (:ParameterJuMP in keys(PSI.get_optimization_container(model).JuMPmodel.ext)) ==
          true
end

@testset "Set optimizer at solve call" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    template = get_thermal_standard_uc_template()
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    UC = DecisionModel(template, c_sys5)
    output_dir = mktempdir(cleanup = true)
    @test build!(UC; output_dir = output_dir) == PSI.BuildStatus.BUILT
    @test solve!(UC; optimizer = GLPK_optimizer) == RunStatus.SUCCESSFUL
    res = ProblemResults(UC)
    @test isapprox(get_objective_value(res), 340000.0; atol = 100000.0)
    vars = res.variable_values
    @test :ActivePowerVariable_ThermalStandard in keys(vars)
    export_results(res)
    results_dir = joinpath(output_dir, "results")
    @test isfile(joinpath(results_dir, "optimizer_stats.csv"))
    variables_dir = joinpath(results_dir, "variables")
    @test isfile(joinpath(variables_dir, "ActivePowerVariable_ThermalStandard.csv"))
end

@testset "Test optimization debugging functions" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    template = get_thermal_standard_uc_template()
    set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    model = DecisionModel(template, c_sys5; optimizer = GLPK_optimizer)
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    container = PSI.get_optimization_container(model)
    MOIU.attach_optimizer(container.JuMPmodel)
    constraint_indices = get_all_constraint_index(model)
    for (key, index, moi_index) in constraint_indices
        val1 = get_con_index(model, moi_index)
        val2 = container.constraints[key].data[index]
        @test val1 == val2
    end
    @test isnothing(get_con_index(model, length(constraint_indices) + 1))

    var_keys = PSI.get_all_var_keys(model)
    var_index = get_all_var_index(model)
    for (ix, (key, index, moi_index)) in enumerate(var_keys)
        index_tuple = var_index[ix]
        @test index_tuple[1] == PSI.encode_key(key)
        @test index_tuple[2] == index
        @test index_tuple[3] == moi_index
        val1 = get_var_index(model, moi_index)
        val2 = container.variables[key].data[index]
        @test val1 == val2
    end
    @test isnothing(get_var_index(model, length(var_index) + 1))
end

# @testset "Test print methods" begin
#     template = ProblemTemplate(CopperPlatePowerModel, devices, branches, services)
#     c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
#     model = DecisionModel(
#         MockOperationProblem,
#         template,
#         c_sys5;
#         optimizer = GLPK_optimizer,
#
#     )
#     list = [template, model, model.container, services]
#     _test_plain_print_methods(list)
#     list = [services]
#     _test_html_print_methods(list)
# end

@testset "Operation Model Solve with Slacks" begin
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    networks = [StandardPTDFModel, DCPPowerModel, ACPPowerModel]
    for network in networks
        template = get_thermal_dispatch_template_network(network)
        model = DecisionModel(
            template,
            c_sys5_re;
            balance_slack_variables = true,
            optimizer = ipopt_optimizer,
            PTDF = PTDF(c_sys5_re),
        )
        @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
        @test solve!(model) == RunStatus.SUCCESSFUL
    end
end

@testset "Default Operations Constructors" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model_ed = EconomicDispatchProblem(c_sys5; output_dir = mktempdir())
    moi_tests(model_ed, false, 120, 0, 120, 120, 24, false)
    model_uc = UnitCommitmentProblem(c_sys5; output_dir = mktempdir())
    moi_tests(model_uc, false, 480, 0, 240, 120, 144, true)
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
    dual_constraint =
        [[:nodal_balance_active__Bus], [:CopperPlateBalance, :network_flow__Line]]
    LMPs = []
    for (ix, network) in enumerate(networks), p in parameters
        template = get_template_dispatch_with_network(network)
        model = DecisionModel(
            template,
            sys;
            optimizer = OSQP_optimizer,
            PTDF = ptdf,
            constraint_duals = dual_constraint[ix],
        )
        @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
        @test solve!(model) == RunStatus.SUCCESSFUL
        res = ProblemResults(model)

        # These tests require results to be working
        if network == StandardPTDFModel
            push!(LMPs, abs.(psi_ptdf_lmps(res, ptdf)))
        else
            duals = res.dual_values[:nodal_balance_active__Bus]
            duals = abs.(duals[:, propertynames(duals) .!== :DateTime])
            push!(LMPs, duals[!, sort(propertynames(duals))])
        end
    end

    @test isapprox(LMPs[1], LMPs[3], atol = 100.0)
end

@testset "Test ProblemResults interfaces" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_re")
    template = get_template_dispatch_with_network(CopperPlatePowerModel)
    model = DecisionModel(
        template,
        sys;
        optimizer = OSQP_optimizer,
        constraint_duals = [:CopperPlateBalance],
    )
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    @test solve!(model) == RunStatus.SUCCESSFUL

    container = PSI.get_optimization_container(model)
    constraints = PSI.get_constraints(container)[PSI.ConstraintKey(
        CopperPlateBalanceConstraint,
        PSY.System,
    )]
    dual_results = read_duals(container, [:CopperPlateBalance])
    for i in axes(constraints)[1]
        dual = JuMP.dual(constraints[i])
        @test isapprox(dual, dual_results[:CopperPlateBalance][i, 1])
    end

    system = PSI.get_system(model)
    params = PSI.get_parameters(container)[:P__max_active_power__PowerLoad]
    param_vals = PSI.axis_array_to_dataframe(params.parameter_array)
    param_mult = PSI.axis_array_to_dataframe(params.multiplier_array)
    for load in get_components(PowerLoad, system)
        name = get_name(load)
        vals = get_time_series_values(Deterministic, load, "max_active_power")
        @test all([-1 * x == get_max_active_power(load) for x in param_mult[!, name]])
        @test all(vals .== param_vals[!, name])
    end

    res = ProblemResults(model)
    @test length(get_existing_variables(res)) == 1
    @test length(get_existing_parameters(res)) == 1
    @test length(get_existing_duals(res)) == 1
    @test get_model_base_power(res) == 100.0
    @test isa(get_objective_value(res), Float64)
    @test isa(get_variables(res), Dict{Symbol, DataFrames.DataFrame})
    @test isa(get_total_cost(res), Float64)
    @test isa(get_optimizer_stats(res), PSI.OptimizerStats)
    @test isa(get_duals(res), Dict{Symbol, DataFrames.DataFrame})
    @test isa(get_parameters(res), Dict{Symbol, DataFrames.DataFrame})
    @test isa(get_resolution(res), Dates.TimePeriod)
    @test isa(get_system(res), PSY.System)
    @test length(get_timestamps(res)) == 24
end

@testset "Test Serialization, deserialization and write optimizer problem" begin
    path = mktempdir(cleanup = true)
    sys = PSB.build_system(PSITestSystems, "c_sys5_re")
    template = get_template_dispatch_with_network(CopperPlatePowerModel)
    model = DecisionModel(
        template,
        sys;
        optimizer = OSQP_optimizer,
        constraint_duals = [:CopperPlateBalance],
    )
    @test build!(model; output_dir = path) == PSI.BuildStatus.BUILT
    @test solve!(model) == RunStatus.SUCCESSFUL

    file_list = sort!(collect(readdir(path)))
    @test "OptimizationModel.json" in file_list
    @test "OperationProblem.bin" in file_list
    filename = joinpath(path, "OperationProblem.bin")
    ED2 = DecisionModel(filename, optimizer = OSQP_optimizer)
    build!(ED2, output_dir = path)
    psi_checksolve_test(ED2, [MOI.OPTIMAL], 240000.0, 10000)

    path2 = mktempdir(cleanup = true)
    model_no_sys = DecisionModel(
        template,
        sys;
        optimizer = OSQP_optimizer,
        system_to_file = false,
        constraint_duals = [:CopperPlateBalance],
    )

    @test build!(model_no_sys; output_dir = path2) == PSI.BuildStatus.BUILT
    @test solve!(model) == RunStatus.SUCCESSFUL

    file_list = sort!(collect(readdir(path2)))
    @test .!all(occursin.(r".h5", file_list))
    filename = joinpath(path2, "OperationProblem.bin")
    ED3 = DecisionModel(filename; system = sys, optimizer = OSQP_optimizer)
    build!(ED3, output_dir = path2)
    psi_checksolve_test(ED3, [MOI.OPTIMAL], 240000.0, 10000)
end

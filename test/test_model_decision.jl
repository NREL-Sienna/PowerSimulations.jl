# TODO: Make more tests with Settings
@testset "Decision Model kwargs" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")

    @test_throws MethodError DecisionModel(template, c_sys5; bad_kwarg = 10)

    model = DecisionModel(template, c_sys5; optimizer = GLPK_optimizer)
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT

    model = DecisionModel(
        MockOperationProblem,
        get_thermal_dispatch_template_network(
            NetworkModel(CopperPlatePowerModel; use_slacks = true),
        ),
        c_sys5_re;
        optimizer = GLPK_optimizer,
    )
    model = DecisionModel(
        get_thermal_dispatch_template_network(),
        c_sys5;
        optimizer = GLPK_optimizer,
    )
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT

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
          false
end

@testset "Set optimizer at solve call" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    template = get_thermal_standard_uc_template()
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "test"),
    )
    UC = DecisionModel(template, c_sys5)
    output_dir = mktempdir(cleanup = true)
    @test build!(UC; output_dir = output_dir) == PSI.BuildStatus.BUILT
    @test solve!(UC; optimizer = GLPK_optimizer) == RunStatus.SUCCESSFUL
    res = ProblemResults(UC)
    @test isapprox(get_objective_value(res), 340000.0; atol = 100000.0)
    vars = res.variable_values
    @test PSI.VariableKey(ActivePowerVariable, PSY.ThermalStandard) in keys(vars)
    export_results(res)
    results_dir = joinpath(output_dir, "results")
    @test isfile(joinpath(results_dir, "optimizer_stats.csv"))
    variables_dir = joinpath(results_dir, "variables")
    @test isfile(joinpath(variables_dir, "ActivePowerVariable_ThermalStandard.csv"))
end

@testset "Test optimization debugging functions" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    template = get_thermal_standard_uc_template()
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "test"),
    )
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
#         MockDecisionProblem,
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

@testset "Decision Model Solve with Slacks" begin
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    networks = [StandardPTDFModel, DCPPowerModel, ACPPowerModel]
    for network in networks
        template = get_thermal_dispatch_template_network(
            NetworkModel(network; use_slacks = true, PTDF = PTDF(c_sys5_re)),
        )
        model = DecisionModel(template, c_sys5_re; optimizer = ipopt_optimizer)
        @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
        @test solve!(model) == RunStatus.SUCCESSFUL
    end
end

@testset "Default Decisions Constructors" begin
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
    ptdf = PTDF(sys)
    # These are the duals of interest for the test
    dual_constraint = [[NodalBalanceActiveConstraint], [CopperPlateBalanceConstraint]]
    LMPs = []
    for (ix, network) in enumerate(networks)
        template = get_template_dispatch_with_network(
            NetworkModel(network; PTDF = ptdf, duals = dual_constraint[ix]),
        )
        if network == StandardPTDFModel
            set_device_model!(
                template,
                DeviceModel(PSY.Line, PSI.StaticBranch; duals = [NetworkFlowConstraint]),
            )
        end
        model = DecisionModel(template, sys; optimizer = OSQP_optimizer)
        @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
        @test solve!(model) == RunStatus.SUCCESSFUL
        res = ProblemResults(model)

        # These tests require results to be working
        if network == StandardPTDFModel
            push!(LMPs, abs.(psi_ptdf_lmps(res, ptdf)))
        else
            duals = read_dual(res, NodalBalanceActiveConstraint, Bus)
            duals = abs.(duals[:, propertynames(duals) .!== :DateTime])
            push!(LMPs, duals[!, sort(propertynames(duals))])
        end
    end
    @test isapprox(LMPs[1], LMPs[2], atol = 100.0)
end

@testset "Test ProblemResults interfaces" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_re")
    template = get_template_dispatch_with_network(
        NetworkModel(CopperPlatePowerModel; duals = [CopperPlateBalanceConstraint]),
    )
    model = DecisionModel(template, sys; optimizer = OSQP_optimizer)
    @test build!(model; output_dir = mktempdir(cleanup = true)) == PSI.BuildStatus.BUILT
    @test solve!(model) == RunStatus.SUCCESSFUL

    container = PSI.get_optimization_container(model)
    constraint_key = PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System)
    constraints = PSI.get_constraints(container)[constraint_key]
    dual_results = PSI.read_duals(container)[constraint_key]
    for i in axes(constraints)[1]
        dual = JuMP.dual(constraints[i])
        @test isapprox(dual, dual_results[i, :CopperPlateBalanceConstraint_System])
    end

    # system = PSI.get_system(model)
    # params = PSI.get_parameter_values(container)[:P__max_active_power__PowerLoad]
    # param_vals = PSI.axis_array_to_dataframe(params.parameter_array)
    # param_mult = PSI.axis_array_to_dataframe(params.multiplier_array)
    # for load in get_components(PowerLoad, system)
    #     name = get_name(load)
    #     vals = get_time_series_values(Deterministic, load, "max_active_power")
    #     @test all([-1 * x == get_max_active_power(load) for x in param_mult[!, name]])
    #     @test all(vals .== param_vals[!, name])
    # end

    res = ProblemResults(model)
    @test length(list_variable_names(res)) == 1
    @test length(list_dual_names(res)) == 1
    @test get_model_base_power(res) == 100.0
    @test isa(get_objective_value(res), Float64)
    @test isa(get_variable_values(res), Dict{PSI.VariableKey, DataFrames.DataFrame})
    @test isa(get_total_cost(res), Float64)
    @test isa(get_optimizer_stats(res), DataFrames.DataFrame)
    @test isa(get_dual_values(res), Dict{PSI.ConstraintKey, DataFrames.DataFrame})
    @test isa(get_parameter_values(res), Dict{PSI.ParameterKey, DataFrames.DataFrame})
    @test isa(get_resolution(res), Dates.TimePeriod)
    @test isa(get_system(res), PSY.System)
    @test length(get_timestamps(res)) == 24
end

@testset "Solve DecisionModelModel with auto-build" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    template = get_thermal_standard_uc_template()
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "test"),
    )
    UC = DecisionModel(template, c_sys5)
    output_dir = mktempdir(cleanup = true)
    @test_throws ErrorException solve!(UC; optimizer = GLPK_optimizer)
    @test solve!(UC; optimizer = GLPK_optimizer, output_dir = output_dir) ==
          RunStatus.SUCCESSFUL
end

@testset "Test Serialization, deserialization and write optimizer problem" begin
    path = mktempdir(cleanup = true)
    sys = PSB.build_system(PSITestSystems, "c_sys5_re")
    template = get_template_dispatch_with_network(
        NetworkModel(CopperPlatePowerModel; duals = [CopperPlateBalanceConstraint]),
    )
    model = DecisionModel(template, sys; optimizer = OSQP_optimizer)
    @test build!(model; output_dir = path) == PSI.BuildStatus.BUILT
    @test solve!(model) == RunStatus.SUCCESSFUL

    file_list = sort!(collect(readdir(path)))
    model_name = PSI.get_name(model)
    @test PSI._JUMP_MODEL_FILENAME in file_list
    @test PSI._SERIALIZED_MODEL_FILENAME in file_list
    ED2 = DecisionModel(path, OSQP_optimizer)
    build!(ED2, output_dir = path)
    solve!(ED2)
    psi_checksolve_test(ED2, [MOI.OPTIMAL], 240000.0, 10000)

    path2 = mktempdir(cleanup = true)
    model_no_sys =
        DecisionModel(template, sys; optimizer = OSQP_optimizer, system_to_file = false)

    @test build!(model_no_sys; output_dir = path2) == PSI.BuildStatus.BUILT
    @test solve!(model_no_sys) == RunStatus.SUCCESSFUL

    file_list = sort!(collect(readdir(path2)))
    @test .!all(occursin.(r".h5", file_list))
    ED3 = DecisionModel(path2, OSQP_optimizer; system = sys)
    build!(ED3, output_dir = path2)
    solve!(ED3)
    psi_checksolve_test(ED3, [MOI.OPTIMAL], 240000.0, 10000)
end

@testset "Test NonSpinning reseve model" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc_non_spin", add_reserves = true)
    template = get_thermal_standard_uc_template()
    set_device_model!(
        template,
        DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserveNonSpinning, NonSpinningReserve, "NonSpinningReserve"),
    )

    UC = DecisionModel(template, c_sys5)
    output_dir = mktempdir(cleanup = true)
    @test build!(UC; output_dir = output_dir) == PSI.BuildStatus.BUILT
    @test solve!(UC; optimizer = Cbc_optimizer) == RunStatus.SUCCESSFUL
    res = ProblemResults(UC)
    @test isapprox(get_objective_value(res), 259346.0; atol = 10000.0)
    vars = res.variable_values
    service_key = PSI.VariableKey(
        ActivePowerReserveVariable,
        PSY.VariableReserveNonSpinning,
        "NonSpinningReserve",
    )
    @test service_key in keys(vars)
end

@testset "Test serialization/deserialization of DecisionModel results" begin
    path = mktempdir(cleanup = true)
    sys = PSB.build_system(PSITestSystems, "c_sys5_re")
    template = get_template_dispatch_with_network(
        NetworkModel(CopperPlatePowerModel; duals = [CopperPlateBalanceConstraint]),
    )
    model = DecisionModel(template, sys; optimizer = OSQP_optimizer)
    @test build!(model; output_dir = path) == PSI.BuildStatus.BUILT
    @test solve!(model, export_problem_results = true) == RunStatus.SUCCESSFUL
    results1 = ProblemResults(model)
    var1_a = read_variable(results1, ActivePowerVariable, ThermalStandard)
    # Ensure that we can deserialize strings into keys.
    var1_b = read_variable(results1, "ActivePowerVariable_ThermalStandard")

    # Results were automatically serialized here.
    results2 = ProblemResults(PSI.get_output_dir(model))
    var2 = read_variable(results2, ActivePowerVariable, ThermalStandard)
    @test var1_a == var2

    # Serialize to a new directory with the exported function.
    results_path = joinpath(path, "results")
    serialize_results(results1, results_path)
    @test isfile(joinpath(results_path, PSI._PROBLEM_RESULTS_FILENAME))
    results3 = ProblemResults(results_path)
    var3 = read_variable(results3, ActivePowerVariable, ThermalStandard)
    @test var1_a == var3
    @test get_system(results3) === nothing
    set_system!(results3, get_system(results1))
    @test get_system(results3) !== nothing

    exp_file =
        joinpath(path, "results", "variables", "ActivePowerVariable_ThermalStandard.csv")
    var4 = PSI.read_dataframe(exp_file)
    @test var1_a == var4
end

@testset "Decision Model kwargs" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")

    @test_throws MethodError DecisionModel(template, c_sys5; bad_kwarg=10)

    model = DecisionModel(template, c_sys5; optimizer=GLPK_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT

    model = DecisionModel(
        MockOperationProblem,
        get_thermal_dispatch_template_network(
            NetworkModel(CopperPlatePowerModel; use_slacks=true),
        ),
        c_sys5_re;
        optimizer=GLPK_optimizer,
    )
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    model = DecisionModel(
        get_thermal_dispatch_template_network(),
        c_sys5;
        optimizer=GLPK_optimizer,
    )
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT

    #"Test passing custom JuMP model"
    my_model = JuMP.Model()
    my_model.ext[:PSI_Testing] = 1
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(
        get_thermal_dispatch_template_network(),
        c_sys5,
        my_model;
        optimizer=GLPK_optimizer,
    )
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
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
    UC = DecisionModel(template, c_sys5; optimizer=GLPK_optimizer)
    output_dir = mktempdir(cleanup=true)
    @test build!(UC; output_dir=output_dir) == PSI.BuildStatus.BUILT
    @test solve!(UC; optimizer=GLPK_optimizer) == RunStatus.SUCCESSFUL
    res = ProblemResults(UC)
    @test isapprox(get_objective_value(res), 340000.0; atol=100000.0)
    vars = res.variable_values
    @test PSI.VariableKey(ActivePowerVariable, PSY.ThermalStandard) in keys(vars)
    @test size(read_variable(res, "StartVariable__ThermalStandard")) == (24, 6)
    @test size(read_parameter(res, "ActivePowerTimeSeriesParameter__PowerLoad")) == (24, 4)
    @test size(read_expression(res, "ProductionCostExpression__ThermalStandard")) == (24, 6)
    @test size(read_aux_variable(res, "TimeDurationOn__ThermalStandard")) == (24, 6)
    @test length(read_variables(res)) == 4
    @test length(read_parameters(res)) == 1
    @test length(read_duals(res)) == 0
    @test length(read_expressions(res)) == 1
    @test read_variables(res, ["StartVariable__ThermalStandard"])["StartVariable__ThermalStandard"] ==
          read_variable(res, "StartVariable__ThermalStandard")
    @test read_variables(res, [(StartVariable, ThermalStandard)])["StartVariable__ThermalStandard"] ==
          read_variable(res, StartVariable, ThermalStandard)
    @test read_parameters(res, ["ActivePowerTimeSeriesParameter__PowerLoad"])["ActivePowerTimeSeriesParameter__PowerLoad"] ==
          read_parameter(res, "ActivePowerTimeSeriesParameter__PowerLoad")
    @test read_parameters(res, [(ActivePowerTimeSeriesParameter, PowerLoad)])["ActivePowerTimeSeriesParameter__PowerLoad"] ==
          read_parameter(res, ActivePowerTimeSeriesParameter, PowerLoad)
    @test read_aux_variables(res, ["TimeDurationOff__ThermalStandard"])["TimeDurationOff__ThermalStandard"] ==
          read_aux_variable(res, "TimeDurationOff__ThermalStandard")
    @test read_aux_variables(res, [(TimeDurationOff, ThermalStandard)])["TimeDurationOff__ThermalStandard"] ==
          read_aux_variable(res, TimeDurationOff, ThermalStandard)
    @test read_expressions(res, ["ProductionCostExpression__ThermalStandard"])["ProductionCostExpression__ThermalStandard"] ==
          read_expression(res, "ProductionCostExpression__ThermalStandard")
    @test read_expressions(res, [(PSI.ProductionCostExpression, ThermalStandard)])["ProductionCostExpression__ThermalStandard"] ==
          read_expression(res, PSI.ProductionCostExpression, ThermalStandard)
    @test length(read_aux_variables(res)) == 2
    @test first(keys(read_aux_variables(res, [(PSI.TimeDurationOff, ThermalStandard)]))) ==
          "TimeDurationOff__ThermalStandard"
    export_results(res)
    results_dir = joinpath(output_dir, "results")
    @test isfile(joinpath(results_dir, "optimizer_stats.csv"))
    variables_dir = joinpath(results_dir, "variables")
    @test isfile(joinpath(variables_dir, "ActivePowerVariable__ThermalStandard.csv"))
end

@testset "Test optimization debugging functions" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    template = get_thermal_standard_uc_template()
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "test"),
    )
    model = DecisionModel(template, c_sys5; optimizer=GLPK_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    container = PSI.get_optimization_container(model)
    MOIU.attach_optimizer(container.JuMPmodel)
    constraint_indices = get_all_constraint_index(model)
    for (key, index, moi_index) in constraint_indices
        val1 = get_constraint_index(model, moi_index)
        val2 = container.constraints[key].data[index]
        @test val1 == val2
    end
    @test get_constraint_index(model, length(constraint_indices) + 1) === nothing

    var_keys = PSI.get_all_variable_keys(model)
    var_index = get_all_variable_index(model)
    for (ix, (key, index, moi_index)) in enumerate(var_keys)
        index_tuple = var_index[ix]
        @test index_tuple[1] == PSI.encode_key(key)
        @test index_tuple[2] == index
        @test index_tuple[3] == moi_index
        val1 = get_variable_index(model, moi_index)
        val2 = container.variables[key].data[index]
        @test val1 == val2
    end
    @test get_variable_index(model, length(var_index) + 1) === nothing
end

@testset "Decision Model Solve with Slacks" begin
    c_sys5_re = PSB.build_system(PSITestSystems, "c_sys5_re")
    networks = [StandardPTDFModel, DCPPowerModel, ACPPowerModel]
    for network in networks
        template = get_thermal_dispatch_template_network(
            NetworkModel(network; use_slacks=true, PTDF=PTDF(c_sys5_re)),
        )
        model = DecisionModel(template, c_sys5_re; optimizer=ipopt_optimizer)
        @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
        @test solve!(model) == RunStatus.SUCCESSFUL
    end
end

@testset "Default Decisions Constructors" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model_ed =
        EconomicDispatchProblem(c_sys5; output_dir=mktempdir(), optimizer=HiGHS_optimizer)
    moi_tests(model_ed, false, 120, 0, 120, 120, 24, false)
    model_uc =
        UnitCommitmentProblem(c_sys5; output_dir=mktempdir(), optimizer=HiGHS_optimizer)
    moi_tests(model_uc, false, 480, 0, 240, 120, 144, true)
    ED_output =
        run_economic_dispatch(c_sys5; output_dir=mktempdir(), optimizer=HiGHS_optimizer)
    UC_output =
        run_unit_commitment(c_sys5; output_dir=mktempdir(), optimizer=HiGHS_optimizer)
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
            NetworkModel(network; PTDF=ptdf, duals=dual_constraint[ix]),
        )
        if network == StandardPTDFModel
            set_device_model!(
                template,
                DeviceModel(PSY.Line, PSI.StaticBranch; duals=[NetworkFlowConstraint]),
            )
        end
        model = DecisionModel(template, sys; optimizer=HiGHS_optimizer)
        @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
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
    @test isapprox(LMPs[1], LMPs[2], atol=100.0)
end

@testset "Test ProblemResults interfaces" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_re")
    template = get_template_dispatch_with_network(
        NetworkModel(CopperPlatePowerModel; duals=[CopperPlateBalanceConstraint]),
    )
    model = DecisionModel(template, sys; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT
    @test solve!(model) == RunStatus.SUCCESSFUL

    res = ProblemResults(model)
    container = PSI.get_optimization_container(model)
    constraint_key = PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System)
    constraints = PSI.get_constraints(container)[constraint_key]
    dual_results = PSI.read_duals(container)[constraint_key]
    dual_results_read = read_dual(res, constraint_key)
    realized_dual_results =
        read_duals(res, [constraint_key])[PSI.encode_key_as_string(constraint_key)]
    realized_dual_results_string =
        read_duals(res, [PSI.encode_key_as_string(constraint_key)])[PSI.encode_key_as_string(
            constraint_key,
        )]
    @test dual_results ==
          dual_results_read[:, propertynames(dual_results_read) .!= :DateTime] ==
          realized_dual_results[:, propertynames(realized_dual_results) .!= :DateTime] ==
          realized_dual_results_string[
              :,
              propertynames(realized_dual_results_string) .!= :DateTime,
          ]
    for i in axes(constraints)[1]
        dual = JuMP.dual(constraints[i])
        @test isapprox(dual, dual_results[i, :CopperPlateBalanceConstraint__System])
    end

    system = PSI.get_system(model)
    parameter_key = PSI.ParameterKey(ActivePowerTimeSeriesParameter, PSY.PowerLoad)
    param_vals = PSI.read_parameters(container)[parameter_key]
    for load in get_components(PowerLoad, system)
        name = get_name(load)
        vals = get_time_series_values(Deterministic, load, "max_active_power")
        vals = vals .* get_max_active_power(load) * -1.0
        @test all(vals .== param_vals[!, name])
    end

    res = ProblemResults(model)
    @test length(list_variable_names(res)) == 1
    @test length(list_dual_names(res)) == 1
    @test get_model_base_power(res) == 100.0
    @test isa(get_objective_value(res), Float64)
    @test isa(res.variable_values, Dict{PSI.VariableKey, DataFrames.DataFrame})
    @test isa(read_variables(res), Dict{String, DataFrames.DataFrame})
    @test isa(PSI.get_total_cost(res), Float64)
    @test isa(get_optimizer_stats(res), DataFrames.DataFrame)
    @test isa(res.dual_values, Dict{PSI.ConstraintKey, DataFrames.DataFrame})
    @test isa(read_duals(res), Dict{String, DataFrames.DataFrame})
    @test isa(res.parameter_values, Dict{PSI.ParameterKey, DataFrames.DataFrame})
    @test isa(read_parameters(res), Dict{String, DataFrames.DataFrame})
    @test isa(PSI.get_resolution(res), Dates.TimePeriod)
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
    UC = DecisionModel(template, c_sys5; optimizer=GLPK_optimizer)
    output_dir = mktempdir(cleanup=true)
    @test_throws ErrorException solve!(UC)
    @test solve!(UC; optimizer=GLPK_optimizer, output_dir=output_dir) ==
          RunStatus.SUCCESSFUL
end

@testset "Test Serialization, deserialization and write optimizer problem" begin
    fpath = mktempdir(cleanup=true)
    sys = PSB.build_system(PSITestSystems, "c_sys5_re")
    template = get_template_dispatch_with_network(
        NetworkModel(CopperPlatePowerModel; duals=[CopperPlateBalanceConstraint]),
    )
    model = DecisionModel(template, sys; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=fpath) == PSI.BuildStatus.BUILT
    @test solve!(model) == RunStatus.SUCCESSFUL

    file_list = sort!(collect(readdir(fpath)))
    model_name = PSI.get_name(model)
    @test PSI._JUMP_MODEL_FILENAME in file_list
    @test PSI._SERIALIZED_MODEL_FILENAME in file_list
    ED2 = DecisionModel(fpath, HiGHS_optimizer)
    @test build!(ED2, output_dir=fpath) == PSI.BuildStatus.BUILT
    psi_checksolve_test(ED2, [MOI.OPTIMAL], 240000.0, 10000)

    path2 = mktempdir(cleanup=true)
    model_no_sys =
        DecisionModel(template, sys; optimizer=HiGHS_optimizer, system_to_file=false)

    @test build!(model_no_sys; output_dir=path2) == PSI.BuildStatus.BUILT
    @test solve!(model_no_sys) == RunStatus.SUCCESSFUL

    file_list = sort!(collect(readdir(path2)))
    @test .!all(occursin.(r".h5", file_list))
    ED3 = DecisionModel(path2, HiGHS_optimizer; system=sys)
    build!(ED3, output_dir=path2)
    psi_checksolve_test(ED3, [MOI.OPTIMAL], 240000.0, 10000)
end

@testset "Test NonSpinning reseve model" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc_non_spin", add_reserves=true)
    template = get_thermal_standard_uc_template()
    set_device_model!(
        template,
        DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment),
    )
    set_service_model!(
        template,
        ServiceModel(VariableReserveNonSpinning, NonSpinningReserve, "NonSpinningReserve"),
    )

    UC = DecisionModel(template, c_sys5, optimizer=HiGHS_optimizer)
    output_dir = mktempdir(cleanup=true)
    @test build!(UC; output_dir=output_dir) == PSI.BuildStatus.BUILT
    @test solve!(UC) == RunStatus.SUCCESSFUL
    res = ProblemResults(UC)
    @test isapprox(get_objective_value(res), 247448.0; atol=10000.0)
    vars = res.variable_values
    service_key = PSI.VariableKey(
        ActivePowerReserveVariable,
        PSY.VariableReserveNonSpinning,
        "NonSpinningReserve",
    )
    @test service_key in keys(vars)
end

@testset "Test serialization/deserialization of DecisionModel results" begin
    path = mktempdir(cleanup=true)
    sys = PSB.build_system(PSITestSystems, "c_sys5_re")
    template = get_template_dispatch_with_network(
        NetworkModel(CopperPlatePowerModel; duals=[CopperPlateBalanceConstraint]),
    )
    model = DecisionModel(template, sys; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=path) == PSI.BuildStatus.BUILT
    @test solve!(model, export_problem_results=true) == RunStatus.SUCCESSFUL
    results1 = ProblemResults(model)
    var1_a = read_variable(results1, ActivePowerVariable, ThermalStandard)
    # Ensure that we can deserialize strings into keys.
    var1_b = read_variable(results1, "ActivePowerVariable__ThermalStandard")

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
        joinpath(path, "results", "variables", "ActivePowerVariable__ThermalStandard.csv")
    var4 = PSI.read_dataframe(exp_file)
    # Manually Multiply by the base power var1_a has natural units and export writes directly from the solver
    @test var1_a[:, propertynames(var1_a) .!= :DateTime] == var4 .* 100.0

    @test length(readdir(export_realized_results(results1))) === 6
end

@testset "Test Numerical Stability of Constraints" begin
    template = get_thermal_dispatch_template_network()
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    valid_bounds = (coefficient=(min=1.0, max=1.0), rhs=(min=0.4, max=9.930296584))
    model = DecisionModel(template, c_sys5; optimizer=GLPK_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT

    bounds = PSI.get_constraint_numerical_bounds(model)
    _check_constraint_bounds(bounds, valid_bounds)

    model_bounds = PSI.get_detailed_constraint_numerical_bounds(model)
    valid_model_bounds = Dict(
        :CopperPlateBalanceConstraint__System => (
            coefficient=(min=1.0, max=1.0),
            rhs=(min=6.434489705000001, max=9.930296584),
        ),
        :ActivePowerVariableLimitsConstraint__ThermalStandard__lb =>
            (coefficient=(min=1.0, max=1.0), rhs=(min=Inf, max=-Inf)),
        :ActivePowerVariableLimitsConstraint__ThermalStandard__ub =>
            (coefficient=(min=1.0, max=1.0), rhs=(min=0.4, max=6.0)),
    )
    for (constriant_key, constriant_bounds) in model_bounds
        _check_constraint_bounds(
            constriant_bounds,
            valid_model_bounds[PSI.encode_key(constriant_key)],
        )
    end
end

@testset "Test Numerical Stability of Variables" begin
    template = get_template_basic_uc_simulation()
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_uc")
    valid_bounds = (min=0.0, max=6.0)
    model = DecisionModel(template, c_sys5; optimizer=GLPK_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == PSI.BuildStatus.BUILT

    bounds = PSI.get_variable_numerical_bounds(model)
    _check_variable_bounds(bounds, valid_bounds)

    model_bounds = PSI.get_detailed_variable_numerical_bounds(model)
    valid_model_bounds = Dict(
        :StopVariable__ThermalStandard => (min=0.0, max=1.0),
        :StartVariable__ThermalStandard => (min=0.0, max=1.0),
        :ActivePowerVariable__ThermalStandard => (min=0.4, max=6.0),
        :OnVariable__ThermalStandard => (min=0.0, max=1.0),
    )
    for (variable_key, variable_bounds) in model_bounds
        _check_variable_bounds(
            variable_bounds,
            valid_model_bounds[PSI.encode_key(variable_key)],
        )
    end
end

@testset "Decision Model initial_conditions test for ThermalGen" begin
    ######## Test with ThermalStandardUnitCommitment ########
    template = get_thermal_standard_uc_template()
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib"; force_build=true)
    set_device_model!(template, ThermalMultiStart, ThermalStandardUnitCommitment)
    model = DecisionModel(template, c_sys5_uc; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    check_duration_on_initial_conditions_values(model, ThermalStandard)
    check_duration_off_initial_conditions_values(model, ThermalStandard)
    @test solve!(model) == RunStatus.SUCCESSFUL

    ######## Test with ThermalMultiStartUnitCommitment ########
    template = get_thermal_standard_uc_template()
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib"; force_build=true)
    set_device_model!(template, ThermalMultiStart, ThermalMultiStartUnitCommitment)
    model = DecisionModel(template, c_sys5_uc; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT

    check_duration_on_initial_conditions_values(model, ThermalStandard)
    check_duration_off_initial_conditions_values(model, ThermalStandard)
    check_duration_on_initial_conditions_values(model, ThermalMultiStart)
    check_duration_off_initial_conditions_values(model, ThermalMultiStart)
    @test solve!(model) == RunStatus.SUCCESSFUL

    ######## Test with ThermalCompactUnitCommitment ########
    template = get_thermal_standard_uc_template()
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib"; force_build=true)
    set_device_model!(template, ThermalMultiStart, ThermalCompactUnitCommitment)
    set_device_model!(template, ThermalStandard, ThermalCompactUnitCommitment)
    model = DecisionModel(template, c_sys5_uc; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    check_duration_on_initial_conditions_values(model, ThermalStandard)
    check_duration_off_initial_conditions_values(model, ThermalStandard)
    check_duration_on_initial_conditions_values(model, ThermalMultiStart)
    check_duration_off_initial_conditions_values(model, ThermalMultiStart)
    @test solve!(model) == RunStatus.SUCCESSFUL
end

@testset "Decision Model initial_conditions test for Storage" begin
    ######## Test with BookKeeping ########
    template = get_thermal_dispatch_template_network()
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat"; force_build=true)
    set_device_model!(template, GenericBattery, BookKeeping)
    model = DecisionModel(template, c_sys5_bat; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    check_energy_initial_conditions_values(model, GenericBattery)
    @test solve!(model) == RunStatus.SUCCESSFUL

    ######## Test with BatteryAncillaryServices ########
    template = get_thermal_dispatch_template_network()
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat"; force_build=true)
    set_device_model!(template, GenericBattery, BatteryAncillaryServices)
    model = DecisionModel(template, c_sys5_bat; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    check_energy_initial_conditions_values(model, GenericBattery)
    @test solve!(model) == RunStatus.SUCCESSFUL

    ######## Test with EnergyTarget ########
    template = get_thermal_dispatch_template_network()
    c_sys5_bat = PSB.build_system(PSITestSystems, "c_sys5_bat_ems"; force_build=true)
    set_device_model!(template, BatteryEMS, EnergyTarget)
    model = DecisionModel(template, c_sys5_bat; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    check_energy_initial_conditions_values(model, BatteryEMS)
    @test solve!(model) == RunStatus.SUCCESSFUL
end

@testset "Decision Model initial_conditions test for Hydro" begin
    ######## Test with HydroDispatchRunOfRiver ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd"; force_build=true)
    set_device_model!(template, HydroDispatch, HydroDispatchRunOfRiver)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchRunOfRiver)
    model = DecisionModel(template, c_sys5_hyd; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test !PSI.has_initial_condition_value(
        initial_conditions_data,
        ActivePowerVariable(),
        HydroEnergyReservoir,
    )
    @test solve!(model) == RunStatus.SUCCESSFUL

    ######## Test with HydroCommitmentRunOfRiver ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd"; force_build=true)
    set_device_model!(template, HydroDispatch, HydroCommitmentRunOfRiver)
    set_device_model!(template, HydroEnergyReservoir, HydroCommitmentRunOfRiver)
    model = DecisionModel(template, c_sys5_hyd; optimizer=HiGHS_optimizer)

    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test PSI.has_initial_condition_value(
        initial_conditions_data,
        OnVariable(),
        HydroEnergyReservoir,
    )
    @test solve!(model) == RunStatus.SUCCESSFUL

    ######## Test with HydroDispatchReservoirBudget ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd"; force_build=true)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirBudget)
    model = DecisionModel(template, c_sys5_hyd; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test !PSI.has_initial_condition_value(
        initial_conditions_data,
        ActivePowerVariable(),
        HydroEnergyReservoir,
    )
    @test solve!(model) == RunStatus.SUCCESSFUL

    ######## Test with HydroCommitmentReservoirBudget ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd"; force_build=true)
    set_device_model!(template, HydroEnergyReservoir, HydroCommitmentReservoirBudget)
    model = DecisionModel(template, c_sys5_hyd; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test PSI.has_initial_condition_value(
        initial_conditions_data,
        OnVariable(),
        HydroEnergyReservoir,
    )
    @test solve!(model) == RunStatus.SUCCESSFUL

    ######## Test with HydroDispatchReservoirStorage ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd_ems"; force_build=true)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirStorage)
    model = DecisionModel(template, c_sys5_hyd; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test !PSI.has_initial_condition_value(
        initial_conditions_data,
        ActivePowerVariable(),
        HydroEnergyReservoir,
    )
    check_energy_initial_conditions_values(model, HydroEnergyReservoir)
    @test solve!(model) == RunStatus.SUCCESSFUL

    ######## Test with HydroCommitmentReservoirStorage ########
    template = get_thermal_dispatch_template_network()
    c_sys5_hyd = PSB.build_system(PSITestSystems, "c_sys5_hyd_ems"; force_build=true)
    set_device_model!(template, HydroEnergyReservoir, HydroCommitmentReservoirStorage)
    model = DecisionModel(template, c_sys5_hyd; optimizer=HiGHS_optimizer)
    @test build!(model; output_dir=mktempdir(cleanup=true)) == BuildStatus.BUILT
    initial_conditions_data =
        PSI.get_initial_conditions_data(PSI.get_optimization_container(model))
    @test PSI.has_initial_condition_value(
        initial_conditions_data,
        OnVariable(),
        HydroEnergyReservoir,
    )
    check_energy_initial_conditions_values(model, HydroEnergyReservoir)
    @test solve!(model) == RunStatus.SUCCESSFUL
end

@testset "Test serialization of InitialConditionsData" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5")
    template = get_thermal_standard_uc_template()
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "test"),
    )
    optimizer = GLPK_optimizer

    # Construct and build with default behavior that builds initial conditions.
    model = DecisionModel(template, sys; optimizer=optimizer)
    output_dir = mktempdir(cleanup=true)

    @test build!(model; output_dir=output_dir) == PSI.BuildStatus.BUILT
    ic_file = PSI.get_initial_conditions_file(model)
    test_ic_serialization_outputs(model, ic_file_exists=true, message="make")
    @test solve!(model) == RunStatus.SUCCESSFUL

    # Build again. Initial conditions should be rebuilt.
    PSI.reset!(model)
    @test build!(model; output_dir=output_dir) == PSI.BuildStatus.BUILT
    test_ic_serialization_outputs(model, ic_file_exists=true, message="make")
    @test solve!(model) == RunStatus.SUCCESSFUL

    # Build again, use existing initial conditions.
    model = DecisionModel(
        template,
        sys;
        optimizer=optimizer,
        deserialize_initial_conditions=true,
    )
    @test build!(model; output_dir=output_dir) == PSI.BuildStatus.BUILT
    test_ic_serialization_outputs(model, ic_file_exists=true, message="deserialize")
    @test solve!(model) == RunStatus.SUCCESSFUL

    # Construct and build again with custom initial conditions file.
    initialization_file = joinpath(output_dir, ic_file * ".old")
    mv(ic_file, initialization_file)
    touch(ic_file)
    model = DecisionModel(
        template,
        sys;
        optimizer=optimizer,
        initialization_file=initialization_file,
        deserialize_initial_conditions=true,
    )
    @test build!(model; output_dir=output_dir) == PSI.BuildStatus.BUILT
    test_ic_serialization_outputs(model, ic_file_exists=true, message="deserialize")
    @test solve!(model) == RunStatus.SUCCESSFUL

    # Construct and build again while skipping build of initial conditions.
    rm(ic_file)
    model = DecisionModel(template, sys; optimizer=optimizer, initialize_model=false)
    @test build!(model; output_dir=output_dir) == PSI.BuildStatus.BUILT
    test_ic_serialization_outputs(model, ic_file_exists=false, message="skip")
    @test solve!(model) == RunStatus.SUCCESSFUL

    # Conflicting inputs
    model = DecisionModel(
        template,
        sys;
        optimizer=optimizer,
        initialize_model=false,
        deserialize_initial_conditions=true,
    )
    @test build!(model; output_dir=output_dir, console_level=Logging.AboveMaxLevel) ==
          PSI.BuildStatus.FAILED
    model = DecisionModel(
        template,
        sys;
        optimizer=optimizer,
        initialize_model=false,
        initialization_file="init_file.bin",
    )
    build!(model; output_dir=output_dir, console_level=Logging.AboveMaxLevel) ==
    PSI.BuildStatus.FAILED
end

@testset "Solve with detailed optimizer stats" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    template = get_thermal_standard_uc_template()
    set_service_model!(
        template,
        ServiceModel(VariableReserve{ReserveUp}, RangeReserve, "test"),
    )
    UC = DecisionModel(
        template,
        c_sys5;
        optimizer=GLPK_optimizer,
        detailed_optimizer_stats=true,
    )
    output_dir = mktempdir(cleanup=true)
    @test build!(UC; output_dir=output_dir) == PSI.BuildStatus.BUILT
    @test solve!(UC) == RunStatus.SUCCESSFUL
    # We only test this field because most free solvers don't support detailed stats
    @test !ismissing(get_optimizer_stats(UC).objective_bound)
end

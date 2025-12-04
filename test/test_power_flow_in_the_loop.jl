@testset "AC Power Flow in the loop for PhaseShiftingTransformer" begin
    system = build_system(PSITestSystems, "c_sys5_uc")

    line = get_component(Line, system, "1")
    arc = get_arc(line)
    remove_component!(system, line)

    ps = PhaseShiftingTransformer(;
        name = get_name(line),
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        r = get_r(line),
        x = get_x(line),
        primary_shunt = 0.0,
        tap = 1.0,
        α = 0.0,
        rating = get_rating(line),
        arc = arc,
        base_power = get_base_power(system),
    )

    add_component!(system, ps)

    template = get_template_dispatch_with_network(
        NetworkModel(
            PTDFPowerModel;
            PTDF_matrix = PTDF(system),
            power_flow_evaluation = ACPowerFlow(),
        ),
    )
    set_device_model!(template, DeviceModel(PhaseShiftingTransformer, PhaseAngleControl))
    model_m = DecisionModel(template, system; optimizer = HiGHS_optimizer)
    @test build!(model_m; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT

    @test solve!(model_m) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    results = OptimizationProblemResults(model_m)
    vd = read_variables(results)

    data = PSI.get_power_flow_data(
        only(PSI.get_power_flow_evaluation_data(PSI.get_optimization_container(model_m))),
    )
    base_power = get_base_power(system)
    phase_results = vd["FlowActivePowerVariable__PhaseShiftingTransformer"]

    # cannot easily test for the "from" bus because of the generators "Park City" and "Alta"
    bus_lookup = PFS.get_bus_lookup(data)
    @test isapprox(
        data.bus_active_power_injections[bus_lookup[get_number(get_to(arc))], :] *
        base_power,
        filter(row -> row[:name] == get_name(line), phase_results)[!, :value],
        atol = 1e-9,
        rtol = 0,
    )
end

@testset "AC Power Flow in the loop with parallel lines" begin
    original_line_flow, parallel_line_flow = zero(ComplexF64), zero(ComplexF64)
    for replace_line in (true, false)
        system = build_system(PSITestSystems, "c_sys5_uc")

        line = get_component(Line, system, "1")
        # split line into 2 parallel lines.
        if replace_line
            original_impedance = get_r(line) + im * get_x(line)
            original_shunt = get_b(line)
            remove_component!(system, line)
            split_impedance = original_impedance * 2
            split_shunt = (from = 0.5 * original_shunt.from, to = 0.5 * original_shunt.to)
            for i in 1:2
                l = Line(;
                    name = get_name(line) * "_$i",
                    available = true,
                    active_power_flow = 0.0,
                    reactive_power_flow = 0.0,
                    arc = get_arc(line),
                    r = real(split_impedance),
                    x = imag(split_impedance),
                    b = split_shunt,
                    angle_limits = get_angle_limits(line),
                    rating = get_rating(line),
                )
                add_component!(system, l)
            end
        end
        template = get_template_dispatch_with_network(
            NetworkModel(
                PTDFPowerModel;
                PTDF_matrix = PTDF(system),
                power_flow_evaluation = ACPowerFlow(),
            ),
        )
        model_m = DecisionModel(template, system; optimizer = HiGHS_optimizer)
        @test build!(model_m; output_dir = mktempdir(; cleanup = true)) ==
              PSI.ModelBuildStatus.BUILT

        @test solve!(model_m) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
        results = OptimizationProblemResults(model_m)
        vd = read_aux_variables(results)
        active_power_ft = vd["PowerFlowLineActivePowerFromTo__Line"]
        reactive_power_ft = vd["PowerFlowLineReactivePowerFromTo__Line"]
        if replace_line
            name = "$(get_name(line))_1"
            parallel_line_flow =
                filter(row -> row[:name] == name, active_power_ft)[1, :value][1] +
                im * filter(row -> row[:name] == name, reactive_power_ft)[1, :value][1]
        else
            name = get_name(line)
            original_line_flow =
                filter(row -> row[:name] == name, active_power_ft)[1, :value][1] +
                im * filter(row -> row[:name] == name, reactive_power_ft)[1, :value][1]
        end
    end

    @test isapprox(
        2 * parallel_line_flow,
        original_line_flow,
        atol = 1e-3,
    )
end

@testset "AC Power Flow in the loop with a breaker-switch" begin
    system = build_system(PSITestSystems, "c_sys5_uc")
    # we choose a line to replace such that the arc lookup of a different line changes.
    line = get_component(Line, system, "2")
    remove_component!(system, line)
    bs = PSY.DiscreteControlledACBranch(
        ;
        name = get_name(line),
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        arc = get_arc(line),
        r = 0.0,
        x = 0.0,
        rating = get_rating(line),
        discrete_branch_type = PSY.DiscreteControlledBranchType.BREAKER,
        branch_status = PSY.DiscreteControlledBranchStatus.CLOSED,
    )
    add_component!(system, bs)
    # these lines end up being parallel, so we set their impedances to be the same
    line3 = get_component(Line, system, "3")
    line6 = get_component(Line, system, "6")
    PSY.set_r!(line3, PSY.get_r(line6))
    PSY.set_x!(line3, PSY.get_x(line6))
    template = get_template_dispatch_with_network(
        NetworkModel(
            PTDFPowerModel;
            PTDF_matrix = PTDF(system),
            power_flow_evaluation = ACPowerFlow(),
        ),
    )
    model_m = DecisionModel(template, system; optimizer = HiGHS_optimizer)

    @test build!(model_m; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    @test solve!(model_m) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    # the interface currently doesn't allow for power flow in-the-loop on networks with
    # reductions. we'd have to pass kwargs all the way down to add_power_flow_data!.
end

@testset "HVDC with AC PF in the loop" begin
    sys = build_system(PSISystems, "RTS_GMLC_DA_sys")

    hvdc = only(get_components(TwoTerminalGenericHVDCLine, sys))
    from = get_from(get_arc(hvdc))
    to = get_to(get_arc(hvdc))

    # remove components that impact total bus power at the HVDC line buses.
    components = collect(
        get_components(
            x -> get_number(get_bus(x)) ∈ (get_number(from), get_number(to)),
            StaticInjection,
            sys,
        ),
    )
    foreach(x -> remove_component!(sys, x), components)
    change_to_PQ = ["Chifa", "Arne"]
    for bus_name in change_to_PQ
        bus = get_component(PSY.ACBus, sys, bus_name)
        @assert !isnothing(bus) "bus does not exist"
        set_bustype!(bus, PSY.ACBusTypes.PQ)
    end

    set_bustype!(get_component(ACBus, sys, "Arthur"), ACBusTypes.REF)

    template_uc =
        ProblemTemplate(NetworkModel(PTDFPowerModel; power_flow_evaluation = ACPowerFlow()))

    set_device_model!(template_uc, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranch))
    set_device_model!(
        template_uc,
        DeviceModel(TwoTerminalGenericHVDCLine, HVDCTwoTerminalDispatch),
    )

    model = DecisionModel(template_uc, sys; name = "UC", optimizer = HiGHS_optimizer)

    @test build!(model; output_dir = mktempdir()) == PSI.ModelBuildStatus.BUILT
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    results = OptimizationProblemResults(model)
    vd = read_variables(results)
    ad = read_aux_variables(results)

    data = PSI.get_power_flow_data(
        only(PSI.get_power_flow_evaluation_data(PSI.get_optimization_container(model))),
    )
    base_power = get_base_power(sys)

    # test that the power flow results for the HVDC buses match the HVDC power transfer from the simulation
    bus_lookup = PFS.get_bus_lookup(data)

    from_to = vd["FlowActivePowerFromToVariable__TwoTerminalGenericHVDCLine"][:, :value]
    to_from = vd["FlowActivePowerToFromVariable__TwoTerminalGenericHVDCLine"][:, :value]

    # needed to add -1 .* here.
    @test isapprox(
        data.bus_active_power_injection[bus_lookup[get_number(from)], :] * base_power,
        -1 .* from_to,
        atol = 1e-9,
        rtol = 0,
    )
    # take into account losses in the HVDC line here. [Why does the above pass, then?]
    hvdc_loss_curve = get_loss(hvdc)
    # check that our hard-coded numbers are correct.
    @assert  hvdc_loss_curve isa PSY.LinearCurve
    @assert get_proportional_term(hvdc_loss_curve) == 0.1
    @assert get_constant_term(hvdc_loss_curve) == 0.0
    nonzeros = (abs.(from_to) .> 1e-9) .| (abs.(to_from) .> 1e-9)
    loss_ratios = (from_to .+ to_from) ./ maximum.(zip(abs.(from_to), abs.(to_from)))
    ten_percent_loss = abs.(loss_ratios .- 0.1) .< 1e-9
    @test all(ten_percent_loss[nonzeros])
end

@testset "Test AC power flow in the loop: small system UCED, PSS/E export" for calculate_loss_factors in
                                                                               (true, false)
    for calculate_voltage_stability_factors in (true, false)
        file_path = mktempdir(; cleanup = true)
        export_path = mktempdir(; cleanup = true)
        pf_path = mktempdir(; cleanup = true)
        c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
        c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
        sim = run_simulation(
            c_sys5_hy_uc,
            c_sys5_hy_ed,
            file_path,
            export_path;
            ed_network_model = NetworkModel(
                CopperPlatePowerModel;
                duals = [CopperPlateBalanceConstraint],
                use_slacks = true,
                power_flow_evaluation =
                ACPowerFlow(;
                    exporter = PSSEExportPowerFlow(:v33, pf_path; write_comments = true),
                    calculate_loss_factors = calculate_loss_factors,
                    calculate_voltage_stability_factors = calculate_voltage_stability_factors,
                ),
            ),
        )
        results = SimulationResults(sim)
        results_ed = get_decision_problem_results(results, "ED")
        thermal_results = first(
            values(
                PSI.read_results_with_keys(results_ed,
                    [PSI.VariableKey(ActivePowerVariable, ThermalStandard)]),
            ),
        )
        min_time = minimum(thermal_results.DateTime)
        max_time = maximum(thermal_results.DateTime)
        first_result = filter(row -> row[:DateTime] == min_time, thermal_results)
        last_result = filter(row -> row[:DateTime] == max_time, thermal_results)

        available_aux_variables = list_aux_variable_keys(results_ed)
        loss_factors_aux_var_key = PSI.AuxVarKey(PowerFlowLossFactors, ACBus)
        voltage_stability_aux_var_key =
            PSI.AuxVarKey(PowerFlowVoltageStabilityFactors, ACBus)

        # here we check if the loss factors are stored in the results, the values are tested in PowerFlows.jl
        if calculate_loss_factors
            @test loss_factors_aux_var_key ∈ available_aux_variables
            loss_factors = first(
                values(
                    PSI.read_results_with_keys(results_ed,
                        [loss_factors_aux_var_key]),
                ),
            )
            @test !isnothing(loss_factors)
            # count distinct time periods
            @test length(unique(loss_factors.DateTime)) == 48 * 12
        else
            @test loss_factors_aux_var_key ∉ available_aux_variables
        end

        if calculate_voltage_stability_factors
            @test voltage_stability_aux_var_key ∈ available_aux_variables
            voltage_stability = first(
                values(
                    PSI.read_results_with_keys(results_ed,
                        [voltage_stability_aux_var_key];
                        table_format = TableFormat.LONG),
                ),
            )
            @test !isnothing(voltage_stability)
            @test length(unique(voltage_stability.DateTime)) == 48 * 12
        else
            @test voltage_stability_aux_var_key ∉ available_aux_variables
        end

        @test length(filter(x -> isdir(joinpath(pf_path, x)), readdir(pf_path))) == 48 * 12
        # this now returns a system?!
        first_export = load_pf_export(pf_path, "export_1_1")
        last_export = load_pf_export(pf_path, "export_48_12")

        # Test that the active powers written to the first and last exports line up with the real simulation results
        for gen_name in get_name.(get_components(ThermalStandard, c_sys5_hy_ed))
            this_first_result =
                filter(row -> row[:name] == gen_name, first_result)[1, :value]
            this_first_exported =
                get_active_power(get_component(ThermalStandard, first_export, gen_name))
            @test isapprox(this_first_result, this_first_exported)

            this_last_result = filter(row -> row[:name] == gen_name, last_result)[1, :value]
            this_last_exported =
                get_active_power(get_component(ThermalStandard, last_export, gen_name))
            @test isapprox(this_last_result, this_last_exported)
        end
    end
end

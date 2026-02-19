@testset "Network DC-PF with VirtualPTDF Model and implementing Dynamic Branch Ratings" begin
    line_device_model = DeviceModel(
        Line,
        StaticBranch;
        time_series_names = Dict(
            DynamicBranchRatingTimeSeriesParameter => "dynamic_line_ratings",
        ))
    TapTransf_device_model = DeviceModel(
        TapTransformer,
        StaticBranch;
        time_series_names = Dict(
            DynamicBranchRatingTimeSeriesParameter => "dynamic_line_ratings",
        ))
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
        c_sys14 => PTDF(c_sys14),
        c_sys14_dc => PTDF(c_sys14_dc),
    )
    branches_dlr = IdDict{System, Vector{String}}(
        c_sys5 => ["1", "2", "6"],
        c_sys14 => ["Line1", "Line2", "Line9", "Line10", "Line12", "Trans2"],
        c_sys14_dc => ["Line1", "Line9", "Line10", "Line12", "Trans2"],
    )
    dlr_factors = vcat([fill(x, 6) for x in [1.15, 1.05, 1.1, 0.95]]...)
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [120, 0, 264, 264, 24],
        c_sys14 => [120, 0, 600, 600, 24],
        c_sys14_dc => [168, 0, 648, 552, 24],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 241293.703,
        c_sys14 => 143365.0,
        c_sys14_dc => 142000.0,
    )
    n_steps = 2
    for (ix, sys) in enumerate(systems)
        add_dlr_to_system_branches!(
            sys,
            branches_dlr[sys],
            n_steps,
            dlr_factors;
            initial_date = "2024-01-01",
        )
        template = get_thermal_dispatch_template_network(
            NetworkModel(
                PTDFPowerModel;
                PTDF_matrix = PTDF_ref[sys],
            ),
        )

        set_device_model!(template, line_device_model)
        set_device_model!(template, TapTransf_device_model)
        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.ModelBuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)

        moi_tests(
            ps_model,
            test_results[sys]...,
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[ix])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.ALMOST_OPTIMAL],
            test_obj_values[sys],
            10000,
        )

        res = OptimizationProblemResults(ps_model)
        for branch_name in branches_dlr[sys]
            branch = get_component(PSY.ACTransmission, sys, branch_name)
            static_rating = get_rating(branch) * get_base_power(sys)
            branch_type = string(typeof(branch))
            flow = read_expression(
                res,
                "PTDFBranchFlow__$branch_type";
                table_format = TableFormat.WIDE,
            )[end,
                branch_name,
            ]
            @test flow <= static_rating * dlr_factors[end] + 1e-5
            @test flow >= -static_rating * dlr_factors[end] - 1e-5
        end
    end
end

@testset "Network DC-PF with PTDF Model and implementing Dynamic Branch Ratings with reductions" begin
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(FlowRateConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
    ]
    branches_dlr = ["1", "2", "6"]
    dlr_factors = vcat([fill(x, 6) for x in [1.15, 1.05, 1.1, 0.95]]...)
    test_results = [120, 0, 264, 264, 24]
    test_obj_values = [381341.0, 340475.0, 241293.703]
    parallel_lines_names_to_add = ["1", "2", "3"]#Add parallel lines in lines with and without DLRs
    n_steps = 2

    line_device_model = DeviceModel(
        Line,
        StaticBranch;
        time_series_names = Dict(
            DynamicBranchRatingTimeSeriesParameter => "dynamic_line_ratings",
        ))
    for (ix, add_parallel_line_name) in enumerate(parallel_lines_names_to_add)
        sys = PSB.build_system(PSITestSystems, "c_sys5")
        line_to_add_parallel = get_component(Line, sys, add_parallel_line_name)
        add_equivalent_ac_transmission_with_parallel_circuits!(
            sys,
            line_to_add_parallel,
            PSY.Line,
        )

        add_dlr_to_system_branches!(
            sys,
            branches_dlr,
            n_steps,
            dlr_factors;
            initial_date = "2024-01-01",
        )

        template = get_thermal_dispatch_template_network(
            NetworkModel(
                PTDFPowerModel;
                PTDF_matrix = PTDF(sys),
            ),
        )
        set_device_model!(template, line_device_model)
        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        @test build!(ps_model; output_dir = mktempdir(; cleanup = true)) ==
              PSI.ModelBuildStatus.BUILT
        psi_constraint_test(ps_model, constraint_keys)

        moi_tests(
            ps_model,
            test_results...,
            false,
        )
        psi_checkobjfun_test(ps_model, objfuncs[1])
        psi_checksolve_test(
            ps_model,
            [MOI.OPTIMAL, MOI.ALMOST_OPTIMAL],
            test_obj_values[ix],
            10000,
        )
    end
end

@testset "Security Constrained Network DC-PF with Virtual PTDF/LODF Model" begin
    template = get_thermal_dispatch_template_network(SecurityConstrainedPTDFPowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
        PSI.ConstraintKey(PostContingencyEmergencyRateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(PostContingencyEmergencyRateLimitConstraint, PSY.Line, "ub"),
    ]
    PTDF_ref = IdDict{System, VirtualPTDF}(
        c_sys5 => VirtualPTDF(c_sys5),
        c_sys14 => VirtualPTDF(c_sys14),
        c_sys14_dc => VirtualPTDF(c_sys14_dc),
    )
    LODF_ref = IdDict{System, VirtualLODF}(
        c_sys5 => VirtualLODF(c_sys5),
        c_sys14 => VirtualLODF(c_sys14),
        c_sys14_dc => VirtualLODF(c_sys14_dc),
    )
    lines_outages = IdDict{System, Vector{String}}(
        c_sys5 => ["1", "2", "3"],
        c_sys14 => ["Line1", "Line2", "Line9", "Line10", "Line12", "Trans2"],
        c_sys14_dc => ["Line1", "Line9", "Line10", "Line12", "Trans2"],
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [264, 0, 624, 624, 168],
        c_sys14 => [600, 0, 3336, 3336, 504],
        c_sys14_dc => [600, 0, 2688, 2592, 456],
    )

    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 445689.358,
        c_sys14 => 141964.156,
        c_sys14_dc => 141964.156,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(
            NetworkModel(
                SecurityConstrainedPTDFPowerModel;
                PTDF_matrix = PTDF_ref[sys],
                LODF_matrix = LODF_ref[sys],
            ),
        )

        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        #Add Outage to a generator and a line which should be neglected for SCUC formulation and test again
        transition_data_gl = GeometricDistributionForcedOutage(;
            mean_time_to_recovery = 20,
            outage_transition_probability = 0.9999,
        )
        generator = first(get_components(ThermalStandard, sys))
        lin = first(get_components(Line, sys))

        add_supplemental_attribute!(sys, generator, transition_data_gl)
        add_supplemental_attribute!(sys, lin, transition_data_gl)
        #Test Expected error since no SCUC valid attributes were added
        @test build!(
            ps_model;
            console_level = Logging.AboveMaxLevel,  # Ignore expected errors.
            output_dir = mktempdir(; cleanup = true),
        ) == PSI.ModelBuildStatus.FAILED

        for branch_name in lines_outages[sys]
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            component = get_component(ACBranch, sys, branch_name)
            add_supplemental_attribute!(sys, component, transition_data)
        end

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
    end
end

@testset "Security Constrained Network DC-PF with PTDF/LODF Model using Rating B for Post-Contingency Flows, dynamic line ratings and outages that should be neglected" begin
    normal_op_dlr_factors = vcat([fill(x, 6) for x in [1.15, 1.05, 1.1, 1.0]]...)
    postcontingency_dlr_factors = vcat([fill(x, 6) for x in [1.25, 1.15, 1.2, 1.1]]...)
    dlr_dict = Dict(
        "dynamic_line_ratings" => normal_op_dlr_factors,
        "Post_contingency_dynamic_line_ratings" => postcontingency_dlr_factors,
    )
    line_device_model = DeviceModel(
        Line,
        StaticBranch;
        time_series_names = Dict(
            DynamicBranchRatingTimeSeriesParameter => collect(keys(dlr_dict))[1],
            PostContingencyDynamicBranchRatingTimeSeriesParameter =>
                collect(keys(dlr_dict))[2],
        ))
    TapTransf_device_model = DeviceModel(
        TapTransformer,
        StaticBranch;
        time_series_names = Dict(
            DynamicBranchRatingTimeSeriesParameter => collect(keys(dlr_dict))[1],
            PostContingencyDynamicBranchRatingTimeSeriesParameter =>
                collect(keys(dlr_dict))[2],
        ))
    template = get_thermal_dispatch_template_network(SecurityConstrainedPTDFPowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
        PSI.ConstraintKey(PostContingencyEmergencyRateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(PostContingencyEmergencyRateLimitConstraint, PSY.Line, "ub"),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
        c_sys14 => PTDF(c_sys14),
        c_sys14_dc => PTDF(c_sys14_dc),
    )
    LODF_ref = IdDict{System, LODF}(
        c_sys5 => LODF(c_sys5),
        c_sys14 => LODF(c_sys14),
        c_sys14_dc => LODF(c_sys14_dc),
    )
    branches_dlr = IdDict{System, Vector{String}}(
        c_sys5 => ["1", "2", "3"],
        c_sys14 => ["Line1", "Line2", "Line9", "Line10", "Line12", "Trans2"],
        c_sys14_dc => ["Line1", "Line9", "Line10", "Line12", "Trans2"],
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [264, 0, 624, 624, 168],
        c_sys14 => [600, 0, 3336, 3336, 504],
        c_sys14_dc => [600, 0, 2688, 2592, 456],
    )
    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 425822.532,
        c_sys14 => 141964.156,
        c_sys14_dc => 141964.156,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(
            NetworkModel(
                SecurityConstrainedPTDFPowerModel;
                PTDF_matrix = PTDF_ref[sys],
                LODF_matrix = LODF_ref[sys],
            ),
        )

        set_device_model!(template, line_device_model)
        set_device_model!(template, TapTransf_device_model)

        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        #Add Outage to a generator and a line which should be neglected for SCUC formulation and test again
        transition_data_gl = GeometricDistributionForcedOutage(;
            mean_time_to_recovery = 20,
            outage_transition_probability = 0.9999,
        )
        generator = first(get_components(ThermalStandard, sys))
        lin = first(get_components(Line, sys))

        add_supplemental_attribute!(sys, generator, transition_data_gl)
        add_supplemental_attribute!(sys, lin, transition_data_gl)
        #Test Expected error since no SCUC valid attributes were added
        @test build!(
            ps_model;
            console_level = Logging.AboveMaxLevel,  # Ignore expected errors.
            output_dir = mktempdir(; cleanup = true),
        ) == PSI.ModelBuildStatus.FAILED

        #Add Outage attribute
        for branch_name in branches_dlr[sys]
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            branch = get_component(ACBranch, sys, branch_name)
            add_supplemental_attribute!(sys, branch, transition_data)
        end

        #Set Rating B for all branches
        for branch in get_components(ACBranch, sys)
            if typeof(branch) == TwoTerminalGenericHVDCLine
                continue
            end
            set_rating_b!(branch, get_rating(branch) * 1.1)
        end

        #Add normal operation and post-contingency DLR time-series
        for (dlr_key, dlr_factors) in dlr_dict
            for branch_name in branches_dlr[sys]
                branch = get_component(ACBranch, sys, branch_name)

                dlr_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
                data_ts = collect(
                    DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
                        "1/1/2024  23:00:00",
                        "d/m/y  H:M:S",
                    ),
                )

                if sys == c_sys5
                    n_steps = 2
                else
                    n_steps = 1
                end

                for t in 1:n_steps
                    ini_time = data_ts[1] + Day(t - 1)
                    dlr_data[ini_time] =
                        TimeArray(
                            data_ts + Day(t - 1),
                            get_rating(branch) * get_base_power(sys) * dlr_factors,
                        )
                end

                PSY.add_time_series!(
                    sys,
                    branch,
                    PSY.Deterministic(
                        dlr_key,
                        dlr_data;
                        scaling_factor_multiplier = get_rating,
                    ),
                )
            end
        end

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
    end
end

@testset "Security Constrained Network DC-PF with PTDF/LODF Model" begin
    template = get_thermal_dispatch_template_network(SecurityConstrainedPTDFPowerModel)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    c_sys14_dc = PSB.build_system(PSITestSystems, "c_sys14_dc")
    systems = [c_sys5, c_sys14, c_sys14_dc]
    objfuncs = [GAEVF, GQEVF, GQEVF]
    constraint_keys = [
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(RateLimitConstraint, PSY.Line, "ub"),
        PSI.ConstraintKey(CopperPlateBalanceConstraint, PSY.System),
        PSI.ConstraintKey(NetworkFlowConstraint, PSY.Line),
        PSI.ConstraintKey(PostContingencyEmergencyRateLimitConstraint, PSY.Line, "lb"),
        PSI.ConstraintKey(PostContingencyEmergencyRateLimitConstraint, PSY.Line, "ub"),
    ]
    PTDF_ref = IdDict{System, PTDF}(
        c_sys5 => PTDF(c_sys5),
        c_sys14 => PTDF(c_sys14),
        c_sys14_dc => PTDF(c_sys14_dc),
    )
    LODF_ref = IdDict{System, LODF}(
        c_sys5 => LODF(c_sys5),
        c_sys14 => LODF(c_sys14),
        c_sys14_dc => LODF(c_sys14_dc),
    )
    lines_outages = IdDict{System, Vector{String}}(
        c_sys5 => ["1", "2", "3"],
        c_sys14 => ["Line1", "Line2", "Line9", "Line10", "Line12", "Trans2"],
        c_sys14_dc => ["Line1", "Line9", "Line10", "Line12", "Trans2"],
    )
    test_results = IdDict{System, Vector{Int}}(
        c_sys5 => [264, 0, 624, 624, 168],
        c_sys14 => [600, 0, 3336, 3336, 504],
        c_sys14_dc => [600, 0, 2688, 2592, 456],
    )

    test_obj_values = IdDict{System, Float64}(
        c_sys5 => 445689.358,
        c_sys14 => 141964.156,
        c_sys14_dc => 141964.156,
    )
    for (ix, sys) in enumerate(systems)
        template = get_thermal_dispatch_template_network(
            NetworkModel(
                SecurityConstrainedPTDFPowerModel;
                PTDF_matrix = PTDF_ref[sys],
                LODF_matrix = LODF_ref[sys],
            ),
        )

        ps_model = DecisionModel(template, sys; optimizer = HiGHS_optimizer)

        #Add Outage to a generator and a line which should be neglected for SCUC formulation and test again
        transition_data_gl = GeometricDistributionForcedOutage(;
            mean_time_to_recovery = 20,
            outage_transition_probability = 0.9999,
        )
        generator = first(get_components(ThermalStandard, sys))
        lin = first(get_components(Line, sys))

        add_supplemental_attribute!(sys, generator, transition_data_gl)
        add_supplemental_attribute!(sys, lin, transition_data_gl)
        #Test Expected error since no SCUC valid attributes were added
        @test build!(
            ps_model;
            console_level = Logging.AboveMaxLevel,  # Ignore expected errors.
            output_dir = mktempdir(; cleanup = true),
        ) == PSI.ModelBuildStatus.FAILED

        for line_name in lines_outages[sys]
            transition_data = GeometricDistributionForcedOutage(;
                mean_time_to_recovery = 10,
                outage_transition_probability = 0.9999,
            )
            component = get_component(ACBranch, sys, line_name)
            add_supplemental_attribute!(sys, component, transition_data)
        end

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
    end
    # SecurityConstrainedPTDF input Error testing
    ps_model = DecisionModel(template, c_sys5; optimizer = HiGHS_optimizer)
    @test build!(
        ps_model;
        console_level = Logging.AboveMaxLevel,  # Ignore expected errors.
        output_dir = mktempdir(; cleanup = true),
    ) == PSI.ModelBuildStatus.FAILED
end

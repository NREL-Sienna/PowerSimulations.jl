HiGHS_optimizer_small_gap = JuMP.optimizer_with_attributes(
    HiGHS.Optimizer,
    "time_limit" => 100.0,
    "log_to_console" => false,
    "mip_rel_gap" => 0.001,
)

function _add_100_MW_reserves!(sys)
    r_up = ConstantReserve{ReserveUp}(
        "ReserveUp",
        true,
        300,
        1.0,
        3600.0,
        1.0,
        1.0,
        0.0,
    )
    add_component!(sys, r_up)
    r1 = get_component(ConstantReserve, sys, "ReserveUp")
    for gen in get_components(ThermalStandard, sys)
        add_service!(gen, r1, sys)
    end
    @assert length(PowerSystems.get_contributing_devices(sys, r1)) == 5
end

function _add_minimum_active_power!(sys)
    for g in get_components(ThermalStandard, sys)
        set_active_power_limits!(g, (min = 0.1, max = get_active_power_limits(g).max))
    end
end

function _set_intertemporal_data!(sys)
    br = get_component(ThermalStandard, sys, "Alta")
    set_time_limits!(br, (up = 2.0, down = 4.0))  #5.0, 5.0 
    #set_ramp_limits!(br, (up = 0.08, down = 0.08))     #TODO - also test ramp limits are respected during outages.
end

function run_events_simulation(;
    sys_emulator,
    outage_time,   #DateTime
    outage_length, #hrs 
    uc_formulation,   #
    ed_formulation,
    feedforward,
    in_memory,
)
    sys_em = deepcopy(sys_emulator)
    _add_minimum_active_power!(sys_em)

    sys_d1 = PSB.build_system(PSISystems, "c_sys5_pjm")
    _add_minimum_active_power!(sys_d1)
    _add_100_MW_reserves!(sys_d1)
    _set_intertemporal_data!(sys_d1)
    transform_single_time_series!(sys_d1, Day(2), Day(1))

    sys_d2 = PSB.build_system(PSISystems, "c_sys5_pjm")
    _add_minimum_active_power!(sys_d2)
    _add_100_MW_reserves!(sys_d2)
    _set_intertemporal_data!(sys_d2)
    transform_single_time_series!(sys_d2, Hour(4), Hour(1))

    event_model = EventModel(
        GeometricDistributionForcedOutage,
        PSI.PresetTimeCondition([outage_time]),
    )
    if uc_formulation == "basic"
        template_d1 = get_template_basic_uc_simulation()
        template_d2 = get_template_basic_uc_simulation()
    elseif uc_formulation == "standard"
        template_d1 = get_template_standard_uc_simulation()
        template_d2 = get_template_standard_uc_simulation()
    else
        @error "invalid uc formulation: $(uc_formulation). Must be basic or standard"
    end
    template_em = get_template_nomin_ed_simulation()
    if ed_formulation == "basic"
        set_device_model!(template_em, ThermalStandard, ThermalBasicDispatch)
    elseif ed_formulation == "nomin"
    else
        @error "invalid ed formulation: $(ed). Must be basic or nomin"
    end

    set_service_model!(template_d1, ServiceModel(ConstantReserve{ReserveUp}, RangeReserve))
    set_service_model!(template_d2, ServiceModel(ConstantReserve{ReserveUp}, RangeReserve))

    for sys in [sys_d1, sys_d2, sys_em]
        outage_gens = ["Alta"]
        for name in outage_gens
            g = get_component(ThermalStandard, sys, name)
            transition_data = PSY.GeometricDistributionForcedOutage(;
                mean_time_to_recovery = outage_length,
                outage_transition_probability = 1.0,
            )
            add_supplemental_attribute!(sys, g, transition_data)
        end
    end

    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_d1,
                sys_d1;
                name = "D1",
                initialize_model = false,
                optimizer = HiGHS_optimizer_small_gap,
            ),
            DecisionModel(
                template_d2,
                sys_d2;
                name = "D2",
                initialize_model = false,
                optimizer = HiGHS_optimizer_small_gap,
                store_variable_names = true,
            ),
        ],
        emulation_model = EmulationModel(
            template_em,
            sys_em;
            name = "EM",
            optimizer = HiGHS_optimizer_small_gap,
            calculate_conflict = true,
            store_variable_names = true,
        ),
    )
    if feedforward
        sequence = SimulationSequence(;
            models = models,
            ini_cond_chronology = InterProblemChronology(),
            feedforwards = Dict(
                "EM" => [# This FeedForward will force the commitment to be kept in the emulator
                    SemiContinuousFeedforward(;
                        component_type = ThermalStandard,
                        source = OnVariable,
                        affected_values = [ActivePowerVariable],
                        #   add_slacks = false, 
                    ),
                ],
            ),
            events = [event_model],
        )
    else
        sequence = SimulationSequence(;
            models = models,
            ini_cond_chronology = InterProblemChronology(),
            events = [event_model],
        )
    end
    sim = Simulation(;
        name = "no_cache",
        steps = 1,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
    build_out = build!(sim; console_level = Logging.Info)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    execute_out = execute!(sim; in_memory = in_memory)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    results = SimulationResults(sim; ignore_status = true)
    return results
end

function test_event_results(;
    res,
    outage_time,
    outage_length,
    expected_power_recovery,
    expected_on_variable_recovery,
)
    em = get_emulation_problem_results(res)
    p = read_realized_variable(em, "ActivePowerVariable__ThermalStandard")
    count = read_realized_variable(
        em,
        "AvailableStatusChangeCountdownParameter__ThermalStandard",
    )
    on = read_realized_variable(em, "OnVariable__ThermalStandard")
    status = read_realized_variable(em, "AvailableStatusParameter__ThermalStandard")
    #tester = read_realized_variable(em, "OnStatusParameter__ThermalStandard")

    outage_ix = indexin([outage_time], p[!, :DateTime])[1]
    outage_length_ix = Int64((Hour(1) / em.resolution) * outage_length)
    on_recover_ix = indexin([expected_on_variable_recovery], p[!, :DateTime])[1]
    p_recover_ix = indexin([expected_power_recovery], p[!, :DateTime])[1]
    #Test condition at time of outage 
    @test count[outage_ix, "Alta"] == 0.0
    @test status[outage_ix, "Alta"] == 1.0
    @test on[outage_ix, "Alta"] == 1.0
    @test p[outage_ix, "Alta"] != 0.0
    #Test condition during outage
    @test count[(outage_ix + 1):(outage_ix + outage_length_ix), "Alta"] ==
          outage_length_ix:-1.0:1.0
    @test status[(outage_ix + 1):(outage_ix + outage_length_ix), "Alta"] ==
          zeros(outage_length_ix)
    @test on[(on_recover_ix - 1), "Alta"] == 0.0  #on variable not necessarily zero for full time; possibly updated later
    @test iszero(p[(outage_ix + 1):(p_recover_ix - 1), "Alta"])
    #Test condition after outage 
    @test count[(outage_ix + outage_length_ix + 1), "Alta"] == 0.0
    @test status[(outage_ix + outage_length_ix + 1), "Alta"] == 1.0
    @test on[on_recover_ix, "Alta"] == 1.0
    @test p[p_recover_ix, "Alta"] != 0.0
    return
end

### HOURLY DATA ### 
#Note: if using basic for ed, emulator fails at timestep  after outage due to OutageConstraint_ub 
@testset "Hourly; uc basic; ed nomin; no ff" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm"),
        outage_time = DateTime("2024-01-01T18:00:00"),
        outage_length = 3.0,
        uc_formulation = "basic",
        ed_formulation = "nomin",
        feedforward = false,
        in_memory = true,
    )
    test_event_results(;
        res = res,
        outage_time = DateTime("2024-01-01T18:00:00"),
        outage_length = 3.0,
        expected_power_recovery = DateTime("2024-01-01T22:00:00"),
        expected_on_variable_recovery = DateTime("2024-01-01T22:00:00"),
    )
end

#This passes with nomin or basic dispatch 
@testset "Hourly; uc basic; ed basic; ff" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm"),
        outage_time = DateTime("2024-01-01T18:00:00"),
        outage_length = 3.0,
        uc_formulation = "basic",
        ed_formulation = "basic",  #should also pass with nomin   
        feedforward = true,
        in_memory = true,
    )
    test_event_results(;
        res = res,
        outage_time = DateTime("2024-01-01T18:00:00"),
        outage_length = 3.0,
        expected_power_recovery = DateTime("2024-01-01T22:00:00"),
        expected_on_variable_recovery = DateTime("2024-01-01T22:00:00"),
    )
end

# Note: Running a standard UC formulation without a feedforward to the ED is not a feasible modeling setup
#Active power can change in Em without regard for OnVariable which messes up initializing the standard UC models. 

# This tests for both min up and down times being handled properly with events.
# Generator not turned back on until 4 hours after the event (event only lasts 3 hours)
# Generator is only on for one hour when the event happens; the constraint is bypassed by resetting the TimeDurationOn variable to a large value. 
@testset "Hourly; uc standard; ed basic; ff" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm"),
        outage_time = DateTime("2024-01-01T17:00:00"),
        outage_length = 3.0,
        uc_formulation = "standard",
        ed_formulation = "basic",  #should also pass with nomin   
        feedforward = true,
        in_memory = true,
    )
    test_event_results(;
        res = res,
        outage_time = DateTime("2024-01-01T17:00:00"),
        outage_length = 3.0,
        expected_power_recovery = DateTime("2024-01-01T22:00:00"),
        expected_on_variable_recovery = DateTime("2024-01-01T22:00:00"),
    )
end

### 5 MINUTE DATA (RESOLUTION MISMATCH) ### 

#Note: if using basic for ed, emulator fails at timestep  after outage due to OutageConstraint_ub 
@testset "5 min; uc basic; ed nomin; no ff" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm_rt"),
        outage_time = DateTime("2024-01-01T18:00:00"),
        outage_length = 3.0,
        uc_formulation = "basic",
        ed_formulation = "nomin",
        feedforward = false,
        in_memory = true,
    )
    test_event_results(;
        res = res,
        outage_time = DateTime("2024-01-01T18:00:00"),
        outage_length = 3.0,
        expected_power_recovery = DateTime("2024-01-01T21:05:00"),
        expected_on_variable_recovery = DateTime("2024-01-01T22:00:00"),
    )
end

@testset "5 min; uc basic; ed basic; ff" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm_rt"),
        outage_time = DateTime("2024-01-01T18:00:00"),
        outage_length = 3.0,
        uc_formulation = "basic",
        ed_formulation = "basic",
        feedforward = true,
        in_memory = false,
    )
    test_event_results(;
        res = res,
        outage_time = DateTime("2024-01-01T18:00:00"),
        outage_length = 3.0,
        expected_power_recovery = DateTime("2024-01-01T22:00:00"),
        expected_on_variable_recovery = DateTime("2024-01-01T22:00:00"),
    )
end

# Note: Running a standard UC formulation without a feedforward to the ED is not a feasible modeling setup
#Active power can change in Em without regard for OnVariable which messes up initializing the standard UC models. 

@testset "5 min; uc standard; ed basic; ff" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm_rt"),
        outage_time = DateTime("2024-01-01T17:00:00"),
        outage_length = 3.0,
        uc_formulation = "standard",
        ed_formulation = "basic",  #should also pass with nomin   
        feedforward = true,
        in_memory = true,
    )
    test_event_results(;
        res = res,
        outage_time = DateTime("2024-01-01T17:00:00"),
        outage_length = 3.0,
        expected_power_recovery = DateTime("2024-01-01T22:00:00"),
        expected_on_variable_recovery = DateTime("2024-01-01T22:00:00"),
    )
end

function _run_fixed_forced_outage_sim_with_timeseries(;
    sys_emulator,
    outage_status_timeseries,
)
    sys_em = deepcopy(sys_emulator)
    _add_minimum_active_power!(sys_em)

    sys_d1 = PSB.build_system(PSISystems, "c_sys5_pjm")
    _add_minimum_active_power!(sys_d1)
    _add_100_MW_reserves!(sys_d1)
    _set_intertemporal_data!(sys_d1)
    transform_single_time_series!(sys_d1, Day(2), Day(1))

    sys_d2 = PSB.build_system(PSISystems, "c_sys5_pjm")
    _add_minimum_active_power!(sys_d2)
    _add_100_MW_reserves!(sys_d2)
    _set_intertemporal_data!(sys_d2)
    transform_single_time_series!(sys_d2, Hour(4), Hour(1))

    event_model = EventModel(
        FixedForcedOutage,
        PSI.ContinuousCondition();
        timeseries_mapping = Dict(
            :outage_status => "outage_profile_1",
        ),
    )
    template_d1 = get_template_basic_uc_simulation()
    template_d2 = get_template_basic_uc_simulation()
    template_em = get_template_nomin_ed_simulation()
    set_device_model!(template_em, ThermalStandard, ThermalBasicDispatch)
    set_service_model!(template_d1, ServiceModel(ConstantReserve{ReserveUp}, RangeReserve))
    set_service_model!(template_d2, ServiceModel(ConstantReserve{ReserveUp}, RangeReserve))

    for sys in [sys_d1, sys_d2, sys_em]
        outage_gens = ["Alta"]
        for name in outage_gens
            g = get_component(ThermalStandard, sys, name)
            transition_data = PSY.FixedForcedOutage(;
                outage_status = 0.0,
            )
            add_supplemental_attribute!(sys, g, transition_data)
            PSY.add_time_series!(
                sys,
                transition_data,
                PSY.SingleTimeSeries("outage_profile_1", outage_status_timeseries),
            )
        end
    end

    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_d1,
                sys_d1;
                name = "D1",
                initialize_model = false,
                optimizer = HiGHS_optimizer_small_gap,
            ),
            DecisionModel(
                template_d2,
                sys_d2;
                name = "D2",
                initialize_model = false,
                optimizer = HiGHS_optimizer_small_gap,
                store_variable_names = true,
            ),
        ],
        emulation_model = EmulationModel(
            template_em,
            sys_em;
            name = "EM",
            optimizer = HiGHS_optimizer_small_gap,
            calculate_conflict = true,
            store_variable_names = true,
        ),
    )
    sequence = SimulationSequence(;
        models = models,
        ini_cond_chronology = InterProblemChronology(),
        feedforwards = Dict(
            "EM" => [# This FeedForward will force the commitment to be kept in the emulator
                SemiContinuousFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [ActivePowerVariable],
                ),
            ],
        ),
        events = [event_model],
    )

    sim = Simulation(;
        name = "no_cache",
        steps = 1,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
    build_out = build!(sim; console_level = Logging.Info)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    execute_out = execute!(sim; in_memory = true)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    results = SimulationResults(sim; ignore_status = true)
    return results
end

@testset "FixedForcedOutage with timeseries" begin
    dates_ts = collect(
        DateTime("2024-01-01T00:00:00"):Hour(1):DateTime("2024-01-07T23:00:00"),
    )
    outage_data = fill!(Vector{Int64}(undef, 168), 0)
    outage_data[3] = 1
    outage_data[10:11] .= 1
    outage_data[23:22] .= 1
    outage_timeseries = TimeArray(dates_ts, outage_data)
    res = _run_fixed_forced_outage_sim_with_timeseries(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm"),
        outage_status_timeseries = outage_timeseries,
    )
    em = get_emulation_problem_results(res)
    status = read_realized_variable(em, "AvailableStatusParameter__ThermalStandard")
    for (ix, x) in enumerate(outage_data[1:24])
        @test x != Int64(status[!, "Alta"][ix])
    end
end

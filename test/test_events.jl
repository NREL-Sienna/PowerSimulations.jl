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
    set_time_limits!(br, (up = 2.0, down = 4.0))
    set_ramp_limits!(br, (up = 0.003, down = 10.0))
end

function _add_interruptible_power_load!(sys)
    b = get_component(ACBus, sys, "nodeA")
    show_components(sys, PowerLoad)
    pl = get_component(PowerLoad, sys, "Bus4")
    ipl = InterruptiblePowerLoad(;
        name = "test_ipl",
        available = true,
        bus = b,
        active_power = 0.0,
        reactive_power = 0.0,
        max_active_power = 1.0,
        max_reactive_power = 1.0,
        base_power = 100.0,
        operation_cost = LoadCost(CostCurve(LinearCurve(100.0)), 100.0),
    )
    add_component!(sys, ipl)
    pl = collect(get_components(PowerLoad, sys))[2]
    tsa = get_time_series_array(SingleTimeSeries, pl, "max_active_power")
    ipl_ts = SingleTimeSeries(;
        name = "max_active_power",
        data = tsa,
    )
    add_time_series!(sys, ipl, ipl_ts)
end

#=
function _add_energy_reservoir_storage!(sys)
    b = get_component(ACBus, sys, "nodeA")
    show_components(sys, PowerLoad)
    pl = get_component(PowerLoad, sys, "Bus4")
    ers = EnergyReservoirStorage(;
        name = "test_ers",
        available = true,
        bus = b,
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        storage_capacity = 4.0,
        storage_level_limits = (min = 0.0, max = 1.0),
        initial_storage_capacity_level = 0.5,
        rating = 4.0,
        active_power = 4.0,
        input_active_power_limits = (min = 0.0, max = 2.0),
        output_active_power_limits = (min = 0.0, max = 2.0),
        efficiency = (in = 0.9, out = 0.9),
        reactive_power = 0.0,
        reactive_power_limits = (min = -2.0, max = 2.0),
        base_power = 100.0,
    )
    add_component!(sys, ers)
end
=#

function run_events_simulation(;
    sys_emulator,
    networks,
    optimizers,
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
        set_network_model!(template_d1, NetworkModel(networks[1]))
        template_d2 = get_template_basic_uc_simulation()
        set_network_model!(template_d2, NetworkModel(networks[2]))
    elseif uc_formulation == "standard"
        template_d1 = get_template_standard_uc_simulation()
        set_network_model!(template_d1, NetworkModel(networks[1]))
        template_d2 = get_template_standard_uc_simulation()
        set_network_model!(template_d2, NetworkModel(networks[2]))
    else
        @error "invalid uc formulation: $(uc_formulation). Must be basic or standard"
    end
    template_em = get_template_nomin_ed_simulation(networks[3])
    if ed_formulation == "basic"
        set_device_model!(template_em, ThermalStandard, ThermalBasicDispatch)
    elseif ed_formulation == "nomin"
    else
        @error "invalid ed formulation: $(ed). Must be basic or nomin"
    end
    set_device_model!(template_d1, Line, StaticBranch)
    set_device_model!(template_d2, Line, StaticBranch)
    set_device_model!(template_em, Line, StaticBranch)

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
                optimizer = optimizers[1],
            ),
            DecisionModel(
                template_d2,
                sys_d2;
                name = "D2",
                initialize_model = false,
                optimizer = optimizers[2],
                store_variable_names = true,
            ),
        ],
        emulation_model = EmulationModel(
            template_em,
            sys_em;
            name = "EM",
            optimizer = optimizers[3],
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
    test_reactive_power = false,
)
    em = get_emulation_problem_results(res)
    p = read_realized_variable(em, "ActivePowerVariable__ThermalStandard")
    count = read_realized_variable(
        em,
        "AvailableStatusChangeCountdownParameter__ThermalStandard",
    )
    on = read_realized_variable(em, "OnVariable__ThermalStandard")
    status = read_realized_variable(em, "AvailableStatusParameter__ThermalStandard")

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
    length_p_zero = p_recover_ix - outage_ix - 1
    @test isapprox(
        p[(outage_ix + 1):(p_recover_ix - 1), "Alta"],
        zeros(length_p_zero);
        atol = 1e-5,
    )
    #Test condition after outage
    @test count[(outage_ix + outage_length_ix + 1), "Alta"] == 0.0
    @test status[(outage_ix + outage_length_ix + 1), "Alta"] == 1.0
    @test on[on_recover_ix, "Alta"] == 1.0
    @test !isapprox(p[p_recover_ix, "Alta"], 0.0; atol = 1e-5)
    if test_reactive_power == true
        q = read_realized_variable(em, "ReactivePowerVariable__ThermalStandard")
        @test isapprox(
            q[(outage_ix + 1):(p_recover_ix - 1), "Alta"],
            zeros(length_p_zero);
            atol = 1e-5,
        )
        @test q[p_recover_ix, "Alta"] != 0.0
        @test !isapprox(q[p_recover_ix, "Alta"], 0.0; atol = 1e-5)
    end
    return
end

### HOURLY DATA ###
#Note: if using basic for ed, emulator fails at timestep  after outage due to OutageConstraint_ub
@testset "Hourly; uc basic; ed nomin; no ff" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm"),
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
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
    #Test no ramping constraint in D2 model results
    d2 = get_decision_problem_results(res, "D2")
    p_d2 = read_realized_variables(d2)["ActivePowerVariable__ThermalStandard"]
    p_recover_ix = indexin([DateTime("2024-01-01T22:00:00")], p_d2[!, :DateTime])[1]
    @test p_d2[p_recover_ix, "Alta"] == 40.0
end

#This passes with nomin or basic dispatch
@testset "Hourly; uc basic; ed basic; ff" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm"),
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
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
    #Test no ramping constraint in D2 model results
    d2 = get_decision_problem_results(res, "D2")
    p_d2 = read_realized_variables(d2)["ActivePowerVariable__ThermalStandard"]
    p_recover_ix = indexin([DateTime("2024-01-01T22:00:00")], p_d2[!, :DateTime])[1]
    @test p_d2[p_recover_ix, "Alta"] == 40.0
end

# Note: Running a standard UC formulation without a feedforward to the ED is not a feasible modeling setup
#Active power can change in Em without regard for OnVariable which messes up initializing the standard UC models.

# This tests for both min up and down times being handled properly with events.
# Generator not turned back on until 4 hours after the event (event only lasts 3 hours)
# Generator is only on for one hour when the event happens; the constraint is bypassed by resetting the TimeDurationOn variable to a large value.
@testset "Hourly; uc standard; ed basic; ff" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm"),
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
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
    #Test ramping constraint in D2 model results
    d2 = get_decision_problem_results(res, "D2")
    p_d2 = read_realized_variables(d2)["ActivePowerVariable__ThermalStandard"]
    p_recover_ix = indexin([DateTime("2024-01-01T22:00:00")], p_d2[!, :DateTime])[1]
    @test p_d2[p_recover_ix, "Alta"] < 40.0
end

### 5 MINUTE DATA (RESOLUTION MISMATCH) ###

#Note: if using basic for ed, emulator fails at timestep  after outage due to OutageConstraint_ub
@testset "5 min; uc basic; ed nomin; no ff" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm_rt"),
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
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
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
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
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
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
    #Test ramping constraint in D2 model results
    d2 = get_decision_problem_results(res, "D2")
    p_d2 = read_realized_variables(d2)["ActivePowerVariable__ThermalStandard"]
    p_recover_ix = indexin([DateTime("2024-01-01T22:00:00")], p_d2[!, :DateTime])[1]
    @test p_d2[p_recover_ix, "Alta"] < 40.0
end

function _run_fixed_forced_outage_sim_with_timeseries(;
    sys_emulator,
    networks,
    optimizers,
    outage_status_timeseries,
    device_type,
    device_names,
    renewable_formulation,
)
    sys_em = deepcopy(sys_emulator)
    _add_minimum_active_power!(sys_em)

    sys_d1 = deepcopy(sys_emulator)
    _add_minimum_active_power!(sys_d1)
    _add_100_MW_reserves!(sys_d1)
    _set_intertemporal_data!(sys_d1)
    transform_single_time_series!(sys_d1, Day(2), Day(1))

    sys_d2 = deepcopy(sys_emulator)
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
    set_network_model!(template_d1, NetworkModel(networks[1]))
    template_d2 = get_template_basic_uc_simulation()
    set_network_model!(template_d2, NetworkModel(networks[2]))
    template_em = get_template_nomin_ed_simulation(networks[3])
    set_device_model!(template_d1, RenewableDispatch, renewable_formulation)
    set_device_model!(template_d2, RenewableDispatch, renewable_formulation)
    set_device_model!(template_em, RenewableDispatch, renewable_formulation)
    set_device_model!(template_em, ThermalStandard, ThermalBasicDispatch)
    set_service_model!(template_d1, ServiceModel(ConstantReserve{ReserveUp}, RangeReserve))
    set_service_model!(template_d2, ServiceModel(ConstantReserve{ReserveUp}, RangeReserve))
    set_device_model!(template_em, InterruptiblePowerLoad, PowerLoadDispatch)
    set_device_model!(template_d1, InterruptiblePowerLoad, PowerLoadDispatch)
    set_device_model!(template_d2, InterruptiblePowerLoad, PowerLoadDispatch)
    storage_device_model = DeviceModel(
        EnergyReservoirStorage,
        StorageDispatchWithReserves;
        attributes = Dict{String, Any}(
            "reservation" => true,
            "cycling_limits" => false,
            "energy_target" => false,
            "complete_coverage" => false,
            "regularization" => true,
        ),
    )
    set_device_model!(template_d1, Line, StaticBranch)
    set_device_model!(template_d2, Line, StaticBranch)
    set_device_model!(template_em, Line, StaticBranch)
    set_device_model!(template_em, storage_device_model)
    set_device_model!(template_d1, storage_device_model)
    set_device_model!(template_d2, storage_device_model)

    for sys in [sys_d1, sys_d2, sys_em]
        for name in device_names
            g = get_component(device_type, sys, name)
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
                optimizer = optimizers[1],
            ),
            DecisionModel(
                template_d2,
                sys_d2;
                name = "D2",
                initialize_model = false,
                optimizer = optimizers[2],
                store_variable_names = true,
            ),
        ],
        emulation_model = EmulationModel(
            template_em,
            sys_em;
            name = "EM",
            optimizer = optimizers[3],
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
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
        outage_status_timeseries = outage_timeseries,
        device_type = ThermalStandard,
        device_names = ["Alta"],
        renewable_formulation = RenewableFullDispatch,
    )
    em = get_emulation_problem_results(res)
    status = read_realized_variable(em, "AvailableStatusParameter__ThermalStandard")
    apv = read_realized_variable(em, "ActivePowerVariable__ThermalStandard")
    for (ix, x) in enumerate(outage_data[1:24])
        @test x != Int64(status[!, "Alta"][ix])
        if Int64(status[!, "Alta"][ix]) == 0.0
            @test apv[!, "Alta"][ix] == 0.0
        end
    end
end

@testset "Renewable outage" begin
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
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
        outage_status_timeseries = outage_timeseries,
        device_type = RenewableDispatch,
        device_names = ["WindBus1"],
        renewable_formulation = RenewableFullDispatch,
    )
    em = get_emulation_problem_results(res)
    status = read_realized_variable(em, "AvailableStatusParameter__RenewableDispatch")
    apv = read_realized_variable(em, "ActivePowerVariable__RenewableDispatch")
    for (ix, x) in enumerate(outage_data[1:24])
        @test x != Int64(status[!, "WindBus1"][ix])
        if Int64(status[!, "WindBus1"][ix]) == 0.0
            @test apv[!, "WindBus1"][ix] == 0.0
        end
    end
end

@testset "Load outage" begin
    dates_ts = collect(
        DateTime("2024-01-01T00:00:00"):Hour(1):DateTime("2024-01-07T23:00:00"),
    )
    outage_data = fill!(Vector{Int64}(undef, 168), 0)
    outage_data[3] = 1
    outage_data[10:11] .= 1
    outage_data[23:22] .= 1
    outage_timeseries = TimeArray(dates_ts, outage_data)
    sys = PSB.build_system(PSISystems, "c_sys5_pjm")
    _add_interruptible_power_load!(sys)
    res = _run_fixed_forced_outage_sim_with_timeseries(;
        sys_emulator = sys,
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
        outage_status_timeseries = outage_timeseries,
        device_type = InterruptiblePowerLoad,
        device_names = ["test_ipl"],
        renewable_formulation = RenewableFullDispatch,
    )
    em = get_emulation_problem_results(res)
    status = read_realized_variable(em, "AvailableStatusParameter__InterruptiblePowerLoad")
    apv = read_realized_variable(em, "ActivePowerVariable__InterruptiblePowerLoad")

    for (ix, x) in enumerate(outage_data[1:24])
        @test x != Int64(status[!, "test_ipl"][ix])
        if Int64(status[!, "test_ipl"][ix]) == 0.0
            @test apv[!, "test_ipl"][ix] == 0.0
        end
    end
end

@testset "Storage outage" begin
    dates_ts = collect(
        DateTime("2024-01-01T00:00:00"):Hour(1):DateTime("2024-01-07T23:00:00"),
    )
    outage_data = fill!(Vector{Int64}(undef, 168), 0)
    outage_data[3] = 1
    outage_data[10:11] .= 1
    outage_data[22:23] .= 1
    outage_timeseries = TimeArray(dates_ts, outage_data)
    sys = PSB.build_system(PSISystems, "c_sys5_pjm")
    _add_energy_reservoir_storage!(sys)
    res = _run_fixed_forced_outage_sim_with_timeseries(;
        sys_emulator = sys,
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
        outage_status_timeseries = outage_timeseries,
        device_type = EnergyReservoirStorage,
        device_names = ["test_ers"],
        renewable_formulation = RenewableFullDispatch,
    )
    em = get_emulation_problem_results(res)
    status = read_realized_variable(em, "AvailableStatusParameter__EnergyReservoirStorage")
    #TODO - modify storage so it is deployed and can test the outages -> check keywords to incentivize.
    apv = read_realized_variable(em, "ActivePowerOutVariable__EnergyReservoirStorage")
    apv = read_realized_variable(em, "ActivePowerInVariable__EnergyReservoirStorage")
    for (ix, x) in enumerate(outage_data[1:24])
        @test x != Int64(status[!, "test_ers"][ix])
        if Int64(status[!, "test_ers"][ix]) == 0.0
            @test apv[!, "test_ers"][ix] == 0.0
        end
    end
end

@testset "StaticPowerLoad outage" begin
    dates_ts = collect(
        DateTime("2024-01-01T00:00:00"):Hour(1):DateTime("2024-01-07T23:00:00"),
    )
    outage_data = fill!(Vector{Int64}(undef, 168), 0)
    outage_timeseries = TimeArray(dates_ts, outage_data)
    sys = PSB.build_system(PSISystems, "c_sys5_pjm")
    res = _run_fixed_forced_outage_sim_with_timeseries(;
        sys_emulator = sys,
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
        outage_status_timeseries = outage_timeseries,
        device_type = PowerLoad,
        device_names = ["Bus2"],
        renewable_formulation = RenewableFullDispatch,
    )
    em = get_emulation_problem_results(res)
    active_power_thermal_no_outage =
        read_realized_variable(em, "ActivePowerVariable__ThermalStandard")
    outage_data[3] = 1
    outage_data[10:11] .= 1
    outage_data[23:22] .= 1
    outage_timeseries = TimeArray(dates_ts, outage_data)
    sys = PSB.build_system(PSISystems, "c_sys5_pjm")
    res = _run_fixed_forced_outage_sim_with_timeseries(;
        sys_emulator = sys,
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
        outage_status_timeseries = outage_timeseries,
        device_type = PowerLoad,
        device_names = ["Bus2"],
        renewable_formulation = RenewableFullDispatch,
    )
    em = get_emulation_problem_results(res)
    status = read_realized_variable(em, "AvailableStatusParameter__PowerLoad")
    active_power_load =
        read_realized_variable(em, "ActivePowerTimeSeriesParameter__PowerLoad")
    active_power_thermal_outage =
        read_realized_variable(em, "ActivePowerVariable__ThermalStandard")
    for (ix, x) in enumerate(outage_data[1:24])
        @test x != Int64(status[!, "Bus2"][ix])
        if outage_data[ix] == 1.0
            change_in_thermal_generation = sum(
                Vector(active_power_thermal_outage[ix, 2:end]) .-
                Vector(active_power_thermal_no_outage[ix, 2:end]),
            )
            active_power_outaged_load = active_power_load[ix, "Bus2"]
            @test isapprox(change_in_thermal_generation, active_power_outaged_load)
        end
    end
end

@testset "FixedOutput outage" begin
    dates_ts = collect(
        DateTime("2024-01-01T00:00:00"):Hour(1):DateTime("2024-01-07T23:00:00"),
    )
    outage_data = fill!(Vector{Int64}(undef, 168), 0)
    outage_timeseries = TimeArray(dates_ts, outage_data)
    sys = PSB.build_system(PSISystems, "c_sys5_pjm")
    res = _run_fixed_forced_outage_sim_with_timeseries(;
        sys_emulator = sys,
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
        outage_status_timeseries = outage_timeseries,
        device_type = PowerLoad,
        device_names = ["Bus2"],
        renewable_formulation = RenewableFullDispatch,
    )
    em = get_emulation_problem_results(res)
    active_power_thermal_no_outage =
        read_realized_variable(em, "ActivePowerVariable__ThermalStandard")
    outage_data[3] = 1
    outage_data[10:11] .= 1
    outage_data[23:22] .= 1
    outage_timeseries = TimeArray(dates_ts, outage_data)
    res = _run_fixed_forced_outage_sim_with_timeseries(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm"),
        networks = repeat([PSI.CopperPlatePowerModel], 3),
        optimizers = repeat([HiGHS_optimizer_small_gap], 3),
        outage_status_timeseries = outage_timeseries,
        device_type = RenewableDispatch,
        device_names = ["WindBus1"],
        renewable_formulation = FixedOutput,
    )
    em = get_emulation_problem_results(res)
    renewable_status =
        read_realized_variable(em, "AvailableStatusParameter__RenewableDispatch")
    active_power_thermal_outage =
        read_realized_variable(em, "ActivePowerVariable__ThermalStandard")
    active_power_renewable =
        read_realized_variable(em, "ActivePowerTimeSeriesParameter__RenewableDispatch")
    for (ix, x) in enumerate(outage_data[1:24])
        @test x != Int64(renewable_status[!, "WindBus1"][ix])
        if outage_data[ix] == 1.0
            change_in_thermal_generation = sum(
                Vector(active_power_thermal_outage[ix, 2:end]) .-
                Vector(active_power_thermal_no_outage[ix, 2:end]),
            )
            active_power_outaged_renewable = active_power_renewable[ix, "WindBus1"]
            @test isapprox(change_in_thermal_generation, active_power_outaged_renewable)
        end
    end
end

@testset "Reactive power formulation w/ outage" begin
    res = run_events_simulation(;
        sys_emulator = PSB.build_system(PSISystems, "c_sys5_pjm"),
        networks = [PSI.PTDFPowerModel, PSI.PTDFPowerModel, PSI.SOCWRPowerModel],
        optimizers = [
            HiGHS_optimizer_small_gap,
            HiGHS_optimizer_small_gap,
            ipopt_optimizer,
        ],
        outage_time = DateTime("2024-01-01T18:00:00"),
        outage_length = 3.0,
        uc_formulation = "basic",
        ed_formulation = "basic",
        feedforward = true,
        in_memory = true,
    )
    test_event_results(;
        res = res,
        outage_time = DateTime("2024-01-01T18:00:00"),
        outage_length = 3.0,
        expected_power_recovery = DateTime("2024-01-01T22:00:00"),
        expected_on_variable_recovery = DateTime("2024-01-01T22:00:00"),
        test_reactive_power = true,
    )
end

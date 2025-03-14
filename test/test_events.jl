function _test_two_stage_standard_outages(sys_d1, sys_d2, sys_em, event_model, add_outage!, in_memory)
    template_d1 = get_template_standard_uc_simulation()
    template_d2 = get_template_standard_uc_simulation()
    template_em = get_template_nomin_ed_simulation()
    set_device_model!(template_em, ThermalStandard, ThermalBasicDispatch)

    for sys in [sys_d1, sys_d2, sys_em]
        add_outage!(sys)  
    end

    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_d1,
                sys_d1;
                name = "D1",
                optimizer = HiGHS_optimizer),
            DecisionModel(
                template_d2,
                sys_d2;
                name = "D2",
                optimizer = HiGHS_optimizer,
            ),
        ],
        emulation_model = EmulationModel(
            template_em,
            sys_em;
            name = "EM",
            optimizer = HiGHS_optimizer,
        ),
    )
    sequence = SimulationSequence(;
        models = models,
        ini_cond_chronology = InterProblemChronology(),
        feedforwards = Dict(
            "D2" => [   #enable D2 to commit more units and lowerbound existing ones instead of fixing
                LowerBoundFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [OnVariable],
                ),
            ],
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
        steps = 2,
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

function _test_two_stage_basic_outages(sys_d1, sys_d2, sys_em, event_model, add_outage!, in_memory)
    template_d1 = get_template_basic_uc_simulation()
    template_d2 = get_template_basic_uc_simulation()
    template_em = get_template_nomin_ed_simulation()
    set_device_model!(template_em, ThermalStandard, ThermalBasicDispatch)

    for sys in [sys_d1, sys_d2, sys_em]
        add_outage!(sys)  
    end

    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_d1,
                sys_d1;
                name = "D1",
                optimizer = HiGHS_optimizer),
            DecisionModel(
                template_d2,
                sys_d2;
                name = "D2",
                optimizer = HiGHS_optimizer,
            ),
        ],
        emulation_model = EmulationModel(
            template_em,
            sys_em;
            name = "EM",
            optimizer = HiGHS_optimizer,
        ),
    )
    sequence = SimulationSequence(;
        models = models,
        ini_cond_chronology = InterProblemChronology(),
        feedforwards = Dict(
            "D2" => [   #enable D2 to commit more units and lowerbound existing ones instead of fixing
                LowerBoundFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [OnVariable],
                ),
            ],
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
    execute_out = execute!(sim; in_memory = in_memory)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    results = SimulationResults(sim; ignore_status = true)
    return results
end 

function _add_fixed_geometric(sys)
    outage_gens = ["Brighton"]
    for name in outage_gens
        g = get_component(ThermalStandard, sys, name)
        transition_data = PSY.GeometricDistributionForcedOutage(;
            mean_time_to_recovery = 3.0,
            outage_transition_probability = 1.0,
        )
        add_supplemental_attribute!(sys, g, transition_data)
    end
end

function _add_time_varying_geometric(sys)
    outage_gens = ["Brighton"]
    res = get_time_series_resolutions(sys)[1]

    dates_ts = collect(
        DateTime("2024-01-01T00:00:00"):res:DateTime("2024-01-07T23:55:00"),
    )   #TODO - get directly from the system so the exact timesteps match automatically 
    outage_index = indexin([DateTime("2024-01-01T04:00:00")], dates_ts)[1]
    mttr_data = fill!(Vector{Float64}(undef, length(dates_ts)), 0)
    mttr_data[outage_index] = 3
    mttr_timeseries = TimeArray(dates_ts, mttr_data)

    outage_prob_data = fill!(Vector{Float64}(undef, length(dates_ts)), 0.0)
    outage_prob_data[outage_index] = 1.0
    outage_prob_timeseries = TimeArray(dates_ts, outage_prob_data)
    for name in outage_gens
        g = get_component(ThermalStandard, sys, name)
        transition_data = PSY.GeometricDistributionForcedOutage(;
            mean_time_to_recovery = 3.0,
            outage_transition_probability = 1.0,
        )
        add_supplemental_attribute!(sys, g, transition_data)
        PSY.add_time_series!(
            sys,
            transition_data,
            PSY.SingleTimeSeries("mttr_profile_1", mttr_timeseries),
        )
        PSY.add_time_series!(
            sys,
            transition_data,
            PSY.SingleTimeSeries("outage_prob_profile_1", outage_prob_timeseries),
        )
    end
end

function _add_minimum_active_power!(sys)
    for g in get_components(ThermalStandard, sys)
        set_active_power_limits!(g, (min = 0.1, max = get_active_power_limits(g).max))
    end
end 

function _set_intertemporal_data!(sys)
    br = get_component(ThermalStandard, sys, "Brighton")
    set_time_limits!(br, (up = 5.0, down = 5.0))
    set_ramp_limits!(br, (up = 0.08, down = 0.08))
end 

emulation_system_1hr = PSB.build_system(PSISystems, "c_sys5_pjm")
emulation_system_5min = PSB.build_system(PSISystems, "c_sys5_pjm_rt") #This fails with dataset write bug


#All combinations should lead to guaranteed outage at "2024-01-01T04:00:00"
condition_outage_combinations = [
    (PSI.PresetTimeCondition([DateTime("2024-01-01T04:00:00")]), _add_fixed_geometric),
    (
        PSI.PresetTimeCondition([DateTime("2024-01-01T04:00:00")]),
        _add_time_varying_geometric,
    ),
    (PSI.ContinuousCondition(), _add_time_varying_geometric),
    #TODO: Test StateVariableValueCondition
    #TODO: Test DiscreteEventCondition
]

#Test ThermalStandard Outage with Basic Formulation 
for sys in [emulation_system_1hr] #, emulation_system_5min]     #TODO - 5 min problem fails in D2 the hour after the outage? need to debug 
    for in_memory in [true, false]
        for condition_outage_combination in condition_outage_combinations
            sys_d1 = PSB.build_system(PSISystems, "c_sys5_pjm")
            _add_minimum_active_power!(sys_d1)
            transform_single_time_series!(sys_d1, Day(2), Day(1))

            sys_d2 = PSB.build_system(PSISystems, "c_sys5_pjm")
            _add_minimum_active_power!(sys_d2)
            transform_single_time_series!(sys_d2, Hour(4), Hour(1))

            sys_em = deepcopy(sys)
            _add_minimum_active_power!(sys)

            condition = condition_outage_combination[1]
            f_outage = condition_outage_combination[2]
            if f_outage == _add_fixed_geometric
                event_model = EventModel(
                    GeometricDistributionForcedOutage,
                    condition,
                )
            elseif f_outage == _add_time_varying_geometric
                event_model = EventModel(
                    GeometricDistributionForcedOutage,
                    condition;
                    timeseries_mapping = Dict(
                        :mean_time_to_recovery => "mttr_profile_1",
                        :outage_transition_probability => "outage_prob_profile_1",
                    ),
                )
            else
                error("Unknown outage function")
            end
            results = _test_two_stage_basic_outages(sys_d1, sys_d2, sys_em, event_model, f_outage, in_memory)
            em = get_emulation_problem_results(results)
            p = read_realized_variable(em, "ActivePowerVariable__ThermalStandard")
            #count = read_realized_variable(em, "AvailableStatusChangeCountdownParameter__ThermalStandard")
            #on = read_realized_variable(em, "OnVariable__ThermalStandard")
            #status = read_realized_variable(em, "AvailableStatusParameter__ThermalStandard")
            #outage_index = indexin([DateTime("2024-01-01T04:00:00")], p_realized[!, :DateTime])[1]
            #TODO - derive tests from count, on, status, outage_index, etc.
            @test p[outage_index, "Brighton"] != 0.0
            @test p[(outage_index + 1), "Brighton"] == 0.0
        end
    end
end
##
#Test ThermalStandard Outage with Standard Formulation (intertemporal constraints)
for sys in [emulation_system_1hr] #, emulation_system_5min]     #TODO - 5 min problem fails in D2 the hour after the outage? need to debug 
    for in_memory in [true, false]
        for condition_outage_combination in condition_outage_combinations
            sys_d1 = PSB.build_system(PSISystems, "c_sys5_pjm")
            _add_minimum_active_power!(sys_d1)
            _set_intertemporal_data!(sys_d1)
            transform_single_time_series!(sys_d1, Day(2), Day(1))

            sys_d2 = PSB.build_system(PSISystems, "c_sys5_pjm")
            _add_minimum_active_power!(sys_d2)
            _set_intertemporal_data!(sys_d2)
            transform_single_time_series!(sys_d2, Hour(4), Hour(1))

            sys_em = deepcopy(sys)
            _add_minimum_active_power!(sys_em)
            _set_intertemporal_data!(sys_em)

            condition = condition_outage_combination[1]
            f_outage = condition_outage_combination[2]
            if f_outage == _add_fixed_geometric
                event_model = EventModel(
                    GeometricDistributionForcedOutage,
                    condition,
                )
            elseif f_outage == _add_time_varying_geometric
                event_model = EventModel(
                    GeometricDistributionForcedOutage,
                    condition;
                    timeseries_mapping = Dict(
                        :mean_time_to_recovery => "mttr_profile_1",
                        :outage_transition_probability => "outage_prob_profile_1",
                    ),
                )
            else
                error("Unknown outage function")
            end
            results = _test_two_stage_standard_outages(sys_d1, sys_d2, sys_em, event_model, f_outage, in_memory)
            em = get_emulation_problem_results(results)
            p = read_realized_variable(em, "ActivePowerVariable__ThermalStandard")
            #count = read_realized_variable(em, "AvailableStatusChangeCountdownParameter__ThermalStandard")
            #on = read_realized_variable(em, "OnVariable__ThermalStandard")
            #status = read_realized_variable(em, "AvailableStatusParameter__ThermalStandard")
            #outage_index = indexin([DateTime("2024-01-01T04:00:00")], p_realized[!, :DateTime])[1]
            #TODO - derive tests from count, on, status, outage_index, etc.
            @test p[outage_index, "Brighton"] != 0.0
            @test p[(outage_index + 1), "Brighton"] == 0.0
        end
    end
end

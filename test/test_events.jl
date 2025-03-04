function _test_two_stage_outages(c_sys5_em::PSY.System, event_model, add_outage!, in_memory)
    template_d1 = get_template_basic_uc_simulation()
    template_d2 = get_template_nomin_ed_simulation()
    template_em = get_template_nomin_ed_simulation()

    set_device_model!(template_em, Line, StaticBranchUnbounded)
    # We remove the services from the template for the emulator to allow the units to "deploy"
    # the reserves
    empty!(template_em.services)
    #set_device_model!(template_d1, PowerLoad, StaticPowerLoad)

    set_device_model!(template_d2, InterruptiblePowerLoad, StaticPowerLoad)
    set_network_model!(template_d1, NetworkModel(
        CopperPlatePowerModel,
        # MILP "duals" not supported with free solvers
        # duals = [CopperPlateBalanceConstraint],
    ))
    set_network_model!(
        template_d2,
        NetworkModel(
            CopperPlatePowerModel;
            duals = [CopperPlateBalanceConstraint],
            use_slacks = true,
        ),
    )

    c_sys5_d1 = PSB.build_system(PSISystems, "c_sys5_pjm")
    transform_single_time_series!(c_sys5_d1, Day(2), Day(1))
    c_sys5_d2 = PSB.build_system(PSISystems, "c_sys5_pjm")
    transform_single_time_series!(c_sys5_d2, Hour(4), Hour(1))

    for sys in [c_sys5_d1, c_sys5_d2, c_sys5_em]
        add_outage!(sys)    #adds outages and relevant timeseries to all three systems.
    end

    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_d1,
                c_sys5_d1;
                name = "D1",
                optimizer = HiGHS_optimizer),
            DecisionModel(
                template_d2,
                c_sys5_d2;
                name = "D2",
                optimizer = ipopt_optimizer,
            ),
        ],
        emulation_model = EmulationModel(
            template_em,
            c_sys5_em;
            name = "EM",
            optimizer = HiGHS_optimizer,
        ),
    )

    sequence = SimulationSequence(;
        models = models,
        ini_cond_chronology = InterProblemChronology(),
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

    em = get_emulation_problem_results(results)
    p_realized = read_realized_variable(em, "ActivePowerVariable__ThermalStandard")
    return p_realized
end

function _add_fixed_geometric(sys)
    outage_gens = ["Brighton"]
    for name in outage_gens
        g = get_component(ThermalStandard, sys, name)
        transition_data = PSY.GeometricDistributionForcedOutage(;
            mean_time_to_recovery = 3,
            outage_transition_probability = 1.0,
        )
        add_supplemental_attribute!(sys, g, transition_data)
    end
end

function _add_time_varying_geometric(sys)
    outage_gens = ["Brighton"]
    res =  get_time_series_resolutions(sys)[1]

    dates_ts = collect(
        DateTime("2024-01-01T00:00:00"):res:DateTime("2024-01-07T23:55:00"),
    )   #TODO - get directly from the system so the exact timesteps match automatically 
    outage_index = indexin([DateTime("2024-01-01T04:00:00")], dates_ts)[1]
    mttr_data = fill!(Vector{Int64}(undef, length(dates_ts)), 0)
    mttr_data[outage_index] = 3
    mttr_timeseries = TimeArray(dates_ts, mttr_data)

    outage_prob_data = fill!(Vector{Float64}(undef, length(dates_ts)), 0.0)
    outage_prob_data[outage_index] = 1.0     
    outage_prob_timeseries = TimeArray(dates_ts, outage_prob_data)
    for name in outage_gens
        g = get_component(ThermalStandard, sys, name)
        transition_data = PSY.GeometricDistributionForcedOutage(;
            mean_time_to_recovery = 3,
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


emulation_system_1hr = PSB.build_system(PSISystems, "c_sys5_pjm")
emulation_system_5min = PSB.build_system(PSISystems, "c_sys5_pjm_rt") #This fails with dataset write bug

conditions = [PSI.PresetTimeCondition([DateTime("2024-01-01T04:00:00")]), ] 

#All combinations should lead to guaranteed outage at "2024-01-01T04:00:00"
condition_outage_combinations = [
    (PSI.PresetTimeCondition([DateTime("2024-01-01T04:00:00")]), _add_fixed_geometric),
    (PSI.PresetTimeCondition([DateTime("2024-01-01T04:00:00")]), _add_time_varying_geometric),
    (PSI.ContinuousCondition(), _add_time_varying_geometric),
    #TODO: Test StateVariableValueCondition
    #TODO: Test DiscreteEventCondition
]

for em_sys in [emulation_system_1hr, emulation_system_5min]
    for in_memory in [true, false]
        for condition_outage_combination in condition_outage_combinations
            sys = deepcopy(em_sys)
            condition = condition_outage_combination[1]
            f_outage = condition_outage_combination[2]
            if f_outage == _add_fixed_geometric
                event_model = EventModel(
                    GeometricDistributionForcedOutage,
                    condition
                )
            elseif f_outage == _add_time_varying_geometric
                event_model = EventModel(
                    GeometricDistributionForcedOutage,
                    condition;
                    timeseries_mapping = Dict(
                        :mean_time_to_recovery => "mttr_profile_1",
                        :outage_transition_probability => "outage_prob_profile_1",
                    )
                )
            else 
                error("Unknown outage function")
            end 
            p_realized = _test_two_stage_outages(sys, event_model, f_outage, in_memory)

            outage_index = indexin([DateTime("2024-01-01T04:00:00")], p_realized[!, :DateTime])[1]

            @test p_realized[outage_index, "Brighton"] != 0.0
            @test p_realized[(outage_index + 1), "Brighton"] == 0.0
        end 
    end 
end 

#TODO: Test Standard Formulations (ramping, min up/down times)
#TODO: Test other device types  
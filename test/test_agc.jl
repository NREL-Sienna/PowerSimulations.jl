
function _remove_all_time_series!(sys)
    for g in get_components(RenewableDispatch, sys)
        remove_time_series!(sys, SingleTimeSeries, g, "max_active_power")
    end
    for g in get_components(ThermalStandard, sys)
        remove_time_series!(sys, SingleTimeSeries, g, "max_active_power")
    end
    for g in get_components(PowerLoad, sys)
        remove_time_series!(sys, SingleTimeSeries, g, "max_active_power")
    end
end 

function set_constant_gen_load_timeseries!(sys; start_time, end_time, resolution, gen_setpoint_levels::Dict)
    ts = collect(start_time:resolution:end_time)
    n_timesteps = length(ts)
    _remove_all_time_series!(sys)
    set_units_base_system!(sys, "NATURAL_UNITS")
    load_capacity = 0
    gen_capacity = 0 
    for l in get_components(PowerLoad, sys)
        load_capacity += PSY.get_max_active_power(l)
    end
    for (gen_name, setpoint) in gen_setpoint_levels 
        gen = get_component(StaticInjection, sys, gen_name)
        gen_capacity += PSY.get_max_active_power(gen) * setpoint
        timeseries_values = ones(n_timesteps) * setpoint 
        add_time_series!(
            sys,
            gen,
            SingleTimeSeries(; name = "max_active_power", data = TimeArray(ts, timeseries_values)),
        )
    end 
    load_timeseries_values =  ones(n_timesteps) *  (gen_capacity / load_capacity) 
    for l in get_components(PowerLoad, sys)
        add_time_series!(
            sys,
            l,
            SingleTimeSeries(; name = "max_active_power", data = TimeArray(ts, load_timeseries_values)),
        )
    end 
    return sys
end 


function run_agc_simulation(
    sys;
    outage_gens = ["Brighton_1"],
    network_model = AreaBalancePowerModel,
    dist_slack = true, 
    area_interchange = true, 
)
    c_sys10_reg_em = deepcopy(sys) 
    c_sys10_reg_d =  deepcopy(sys) 
    PSY.transform_single_time_series!(c_sys10_reg_d, Minute(10), Minute(10))
    outage_length = 1   #hours 
    for sys in [c_sys10_reg_em, c_sys10_reg_d]
        outage_gens =outage_gens
        for name in outage_gens
            g = get_component(ThermalStandard, sys, name)
            transition_data = PSY.GeometricDistributionForcedOutage(;
                mean_time_to_recovery = outage_length,
                outage_transition_probability = 1.0,
            )
            add_supplemental_attribute!(sys, g, transition_data)
        end
    end 
    if dist_slack == true && network_model == AreaPTDFPowerModel
        buscount = length(PSY.get_available_components(PSY.ACBus, sys))
        busnumbers = PSY.get_number.(PSY.get_available_components(PSY.ACBus, sys))
        slack_array = 1 / buscount * ones(buscount)
        slack_dict = Dict(i => slack_array[ix] / sum(slack_array) for (ix, i) in enumerate(busnumbers))
        ptdf = PTDF(sys; dist_slack = slack_dict)
        template_d = ProblemTemplate(NetworkModel(AreaPTDFPowerModel; PTDF_matrix = ptdf))
    else 
        template_d = ProblemTemplate(network_model)
    end 
    device_model = DeviceModel(
        PSY.ThermalStandard,
        FixedOutput;
        time_series_names = Dict{Type{<:PSI.TimeSeriesParameter}, String}(
            PSI.ActivePowerTimeSeriesParameter => "max_active_power",
        ),
    )
    set_device_model!(template_d, device_model)
    area_interchange && set_device_model!(template_d, PSY.AreaInterchange, StaticBranch)
    area_interchange && set_device_model!(template_d, PSY.MonitoredLine, StaticBranch)
    set_device_model!(template_d, PSY.PowerLoad, StaticPowerLoad)
    if dist_slack == true && network_model == AreaPTDFPowerModel
        buscount = length(PSY.get_available_components(PSY.ACBus, sys))
        busnumbers = PSY.get_number.(PSY.get_available_components(PSY.ACBus, sys))
        slack_array = 1 / buscount * ones(buscount)
        slack_dict = Dict(i => slack_array[ix] / sum(slack_array) for (ix, i) in enumerate(busnumbers))
        ptdf = PTDF(sys; dist_slack = slack_dict)
        template_em = ProblemTemplate(NetworkModel(AreaPTDFPowerModel; PTDF_matrix = ptdf))
    else 
        template_em = ProblemTemplate(network_model)
    end 
    device_model = DeviceModel(
        PSY.ThermalStandard,
        FixedOutput;
        time_series_names = Dict{Type{<:PSI.TimeSeriesParameter}, String}(
            PSI.ActivePowerTimeSeriesParameter => "max_active_power",
        ),
    )
    set_device_model!(template_em, device_model)
    area_interchange && set_device_model!(template_em, PSY.AreaInterchange, StaticBranchUnbounded)   
    area_interchange && set_device_model!(template_em, PSY.MonitoredLine, StaticBranchUnbounded)
        
    set_device_model!(template_em, PSY.PowerLoad, StaticPowerLoad)   
    set_service_model!(template_em, ServiceModel(PSY.AGC, PIDSmoothACE))

    models = SimulationModels(;
        decision_models = DecisionModel[
            DecisionModel(
                name = "decision",
                template_d, 
                c_sys10_reg_d;
                calculate_conflict = true,
                optimizer = HiGHS_optimizer, 
            )
        ],
        emulation_model  = EmulationModel(
            template_em,
            c_sys10_reg_em;
            name = "EM",
            calculate_conflict = true,
            optimizer = HiGHS_optimizer,
        )
    )
    event_model = [EventModel(
        GeometricDistributionForcedOutage,
        PSI.PresetTimeCondition([DateTime("2024-01-01T00:02:00")]); #Outage AFTER third timestamp.
    )]
    if area_interchange
        feedforwards = Dict(
                "EM" => [
                    FixValueFeedforward(;
                        component_type = AreaInterchange,
                        source = FlowActivePowerVariable,
                        affected_values = [ScheduledFlowActivePowerVariable],
                    ),
                ],
             )
        sequence = SimulationSequence(;
            models = models,
            ini_cond_chronology = InterProblemChronology(),
            events = event_model,  
            feedforwards = feedforwards,   #Try without feedforwards
        )
    else 
        sequence = SimulationSequence(;
            models = models,
            ini_cond_chronology = InterProblemChronology(),
            events = event_model,  
        )
    end 
    sim = Simulation(;
        name = "agc-test",
        steps = 1,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(), #joinpath(".", "agc-store"),
        initial_time = DateTime("2024-01-01T00:00:00"),
    )
    build!(sim)
    execute!(sim; in_memory = false)
    res = SimulationResults(sim)
    return sim, res 
end 


function test_area_agc_deployments(
    res_em;
    net_deployment, 
    net_additional_deployment, 
    Δf_settle, 
    ΔP_interchange_settle, 
)
    up = read_realized_variable(res_em, "DeltaActivePowerUpExpression__Area"; table_format = TableFormat.WIDE)
    down = read_realized_variable(res_em, "DeltaActivePowerDownExpression__Area"; table_format = TableFormat.WIDE)
    additional_up = read_realized_variable(res_em, "AdditionalDeltaActivePowerUpExpression__Area"; table_format = TableFormat.WIDE)
    additional_down = read_realized_variable(res_em, "AdditionalDeltaActivePowerDownExpression__Area"; table_format = TableFormat.WIDE)
    Δf = read_realized_variable(res_em, "SteadyStateFrequencyDeviation__AGC"; table_format = TableFormat.WIDE)
    ΔP_interchange = read_realized_variable(res_em, "FlowActivePowerVariable__AreaInterchange"; table_format = TableFormat.WIDE)
    for (area_key, value) in net_deployment
        net = up[!, area_key][end] - down[!, area_key][end]
        @test isapprox(net, value; atol=1e-3)
    end 
    for (area_key, value) in net_additional_deployment
        net_additional = additional_up[!, area_key][end] - additional_down[!, area_key][end]
        @test isapprox(net_additional, value; atol=1e-3)
    end 
    @test isapprox(Δf[!, "SteadyStateFrequencyDeviation__AGC"][end], Δf_settle; atol=1e-4)
    @test isapprox(ΔP_interchange[!, "1_2"][end], ΔP_interchange_settle; atol=1e-4)
end 

@testset "AreaPTDFPowerModel---no saturation" begin 
    sys = PSB.build_system(PSISystems, "two_area_pjm_DA"; add_agc = true)
    gen_setpoints = Dict(name => 0.5 for name in get_name.(get_components(ThermalStandard, sys)))
    set_constant_gen_load_timeseries!(
        sys;
        start_time = DateTime("2024-01-01T00:00:00"), 
        end_time = DateTime("2024-01-01T00:20:00"),
        resolution = Minute(1),
        gen_setpoint_levels = gen_setpoints
    )
    sim, res = run_agc_simulation(
        sys;
        outage_gens = ["Alta_2"], 
        network_model = AreaPTDFPowerModel,
        dist_slack =true, 
        area_interchange = true, 
    );
    res_em = get_emulation_problem_results(res)
    test_area_agc_deployments(
        res_em;
        net_deployment = Dict("Area1" => 0.0, "Area2" => 20.0),
        net_additional_deployment = Dict("Area1" => 0.0, "Area2" => 0.0),
        Δf_settle = 0.0, 
        ΔP_interchange_settle = 0.0, 
    )
end 

@testset "AreaPTDFPowerModel --- saturation" begin 
    sys = PSB.build_system(PSISystems, "two_area_pjm_DA"; add_agc = true)
    gen_setpoints = Dict(name => 0.5 for name in get_name.(get_components(ThermalStandard, sys)))
    set_constant_gen_load_timeseries!(
        sys;
        start_time = DateTime("2024-01-01T00:00:00"), 
        end_time = DateTime("2024-01-01T00:20:00"),
        resolution = Minute(1),
        gen_setpoint_levels = gen_setpoints
    )
    sim, res = run_agc_simulation(
        sys;
        outage_gens = ["Brighton_1"], 
        network_model = AreaPTDFPowerModel,
        area_interchange = true, 
    );
    res_em = get_emulation_problem_results(res)
    test_area_agc_deployments(
        res_em;
        net_deployment = Dict("Area1" => 100.0, "Area2" => 0.0),
        net_additional_deployment = Dict("Area1" => 200.0, "Area2" => 0.0),
        Δf_settle = 0.0, 
        ΔP_interchange_settle = 0.0, 
    )
end 

# why does Area2 deploy downward reserve? - related to solution, if the cost of additional reserves is high enough, we don't see this...
@testset "AreaPTDFPowerModel --- shortfall in area; need to import" begin 
    sys = PSB.build_system(PSISystems, "two_area_pjm_DA"; add_agc = true)
    gen_setpoints = Dict(name => 0.8 for name in get_name.(get_components(ThermalStandard, sys)))
    set_constant_gen_load_timeseries!(
        sys;
        start_time = DateTime("2024-01-01T00:00:00"), 
        end_time = DateTime("2024-01-01T00:20:00"),
        resolution = Minute(1),
        gen_setpoint_levels = gen_setpoints
    )
    sim, res = run_agc_simulation(
        sys;
        outage_gens = ["Brighton_1"], 
        network_model = AreaPTDFPowerModel,
        area_interchange = true, 
    );
    res_em = get_emulation_problem_results(res)
    test_area_agc_deployments(
        res_em;
        net_deployment = Dict("Area1" => 40.0, "Area2" => 40.0),              
        net_additional_deployment = Dict("Area1" => 266.0, "Area2" => 129.3538),   
        Δf_settle = -0.0002323,                                                        
        ΔP_interchange_settle = -171.677,                                                       
    )
end 

@testset "AreaPTDFPowerModel --- non-zero scheduled interchange" begin 
    sys = PSB.build_system(PSISystems, "two_area_pjm_DA"; add_agc = true)
    gen_setpoints = Dict(name => 0.5 for name in get_name.(get_components(ThermalStandard, sys)))
    gen_setpoints["Brighton_1"] = 0.6
    set_constant_gen_load_timeseries!(
        sys;
        start_time = DateTime("2024-01-01T00:00:00"), 
        end_time = DateTime("2024-01-01T00:20:00"),
        resolution = Minute(1),
        gen_setpoint_levels = gen_setpoints
    )
    sim, res = run_agc_simulation(
        sys;
        outage_gens = ["Alta_1"], 
        network_model = AreaPTDFPowerModel,
        area_interchange = true, 
    );
    res_em = get_emulation_problem_results(res)
    res_d = get_decision_problem_results(res, "decision")
    test_area_agc_deployments(
        res_em;
        net_deployment = Dict("Area1" => 20.0, "Area2" => 0.0),              
        net_additional_deployment = Dict("Area1" => 0.0, "Area2" => 0.0),   
        Δf_settle = 0.0,                                                        
        ΔP_interchange_settle = 30.0,                                                     
    )
end 

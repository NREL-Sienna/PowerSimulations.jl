using Revise

using PowerSystems
using PowerSystemCaseBuilder
using InfrastructureSystems
using PowerNetworkMatrices
using TimeSeries
using HydroPowerSimulations
using PowerSimulations
using StorageSystemsSimulations
using HiGHS
using Xpress
using JuMP
using Dates

const PSY = PowerSystems
const IF = InfrastructureSystems
const PSB = PowerSystemCaseBuilder
const PNM = PowerNetworkMatrices
const PSI = PowerSimulations

##############################################################################
# create new system ##########################################################

sys_dict = Dict()

for sys_name in ["RTS_GMLC_DA_sys", "RTS_GMLC_RT_sys"]

    # get the systems
    main_sys = PSB.build_system(PSISystems, sys_name)
    twin_sys = deepcopy(main_sys)
    names = [
        "114_SYNC_COND_1",
        "314_SYNC_COND_1",
        "313_STORAGE_1",
        "214_SYNC_COND_1",
        "212_CSP_1",
    ]
    for sys in [main_sys, twin_sys]
        for d in get_components(x -> get_fuel(x) == ThermalFuels.DISTILLATE_FUEL_OIL, ThermalStandard, sys)
            for s in get_services(d)
                remove_service!(d, s)
            end
            remove_component!(sys, d)
        end
        for d in PSY.get_components(x -> x.name ∈ names, PSY.Generator, sys)
            for s in get_services(d)
                remove_service!(d, s)
            end
            remove_component!(sys, d)
        end
        for d in get_components(x -> get_fuel(x) == ThermalFuels.NUCLEAR, ThermalStandard, sys)
            set_must_run!(d, true)
        end
    end

    # clear time series
    PSY.clear_time_series!(twin_sys)

    # change names of the systems
    PSY.set_name!(main_sys, "main")
    PSY.set_name!(twin_sys, "twin")

    # change the names of the areas and loadzones first
    for type_ in [PSY.Area, PSY.LoadZone]
        for b in PSY.get_components(type_, twin_sys)
            name_ = PSY.get_name(b)
            main_comp = PSY.get_component(type_, main_sys, name_)
            # remove the component
            PSY.remove_component!(twin_sys, b)
            # change name
            PSY.set_name!(b, name_ * "_twin")
            # define time series container
            IF.assign_new_uuid!(b)
            # add comopnent to the new sys (main)
            PSY.add_component!(main_sys, b)
            # check if it has timeseries
            if PSY.has_time_series(main_comp)
                PSY.copy_time_series!(b, main_comp)
            end
        end
    end

    # now add the buses
    for b in PSY.get_components(PSY.ACBus, twin_sys)
        name_ = PSY.get_name(b)
        main_comp = PSY.get_component(PSY.ACBus, main_sys, name_)
        # remove the component
        PSY.remove_component!(twin_sys, b)
        # change name
        PSY.set_name!(b, name_ * "_twin")
        # change area
        PSY.set_area!(b, PSY.get_component(Area, main_sys, PSY.get_name(PSY.get_area(main_comp)) * "_twin"))
        # change number
        PSY.set_number!(b, PSY.get_number(b) + 10000)
        # add comopnent to the new sys (main)
        IF.assign_new_uuid!(b)
        PSY.add_component!(main_sys, b)
    end

    # now add the Lines
    from_to_list = []
    for b in PSY.get_components(PSY.Line, twin_sys)
        name_ = PSY.get_name(b)
        main_comp = PSY.get_component(PSY.Line, main_sys, name_)
        # remove the component
        PSY.remove_component!(twin_sys, b)
        b.time_series_container = IF.TimeSeriesContainer()
        # change name
        PSY.set_name!(b, name_ * "_twin")
        # create new component from scratch since copying is not working
        new_arc = PSY.Arc(
            from = PSY.get_component(
                ACBus,
                main_sys,
                PSY.get_name(PSY.get_from_bus(main_comp)) * "_twin"
                ),
            to = PSY.get_component(
                ACBus,
                main_sys,
                PSY.get_name(PSY.get_to_bus(main_comp)) * "_twin"
                )
        )
        # # add arc to the system
        from_to = (PSY.get_name(new_arc.from), get_name(new_arc.to))
        if !(from_to in from_to_list)
            push!(from_to_list, from_to)
            PSY.add_component!(main_sys, new_arc)
        end
        PSY.set_arc!(b, new_arc)
        # add comopnent to the new sys (main)
        IF.assign_new_uuid!(b)
        PSY.add_component!(main_sys, b)
    end

    # get the services from twin_sys to main_sys
    for srvc in PSY.get_components(PSY.Service, twin_sys)
        name_ = PSY.get_name(srvc)
        main_comp = PSY.get_component(PSY.Service, main_sys, name_)
        # remove the component
        PSY.remove_component!(twin_sys, srvc)
        # change name
        PSY.set_name!(srvc, name_ * "_twin")
        # define time series container
        IF.assign_new_uuid!(srvc)
        # add comopnent to the new sys (main)
        PSY.add_component!(main_sys, srvc)
        # check if it has timeseries
        if PSY.has_time_series(main_comp)
            PSY.copy_time_series!(srvc, main_comp)
        end
    end

    # finally add the remaining devices (lines are not present since removed before)
    for b in PSY.get_components(Device, twin_sys)
        name_ = PSY.get_name(b)
        main_comp = PSY.get_component(typeof(b), main_sys, name_)
        # remove the component and services
        PSY.clear_services!(b)
        PSY.remove_component!(twin_sys, b)
        # change name
        PSY.set_name!(b, name_ * "_twin")
        # change bus (already changed)
        # check if it has services
        @assert !PSY.has_service(b, PSY.VariableReserve)
        #check if component has time_series
        if !PSY.has_time_series(b)
            # define time series container
            IF.assign_new_uuid!(b)
            # add comopnent to the new sys (main)
            PSY.add_component!(main_sys, b)
            PSY.copy_time_series!(b, main_comp)
        else
            IF.assign_new_uuid!(b)
            PSY.add_component!(main_sys, b)
        end
        # add service to the device to be added to main_sys
        if length(PSY.get_services(main_comp)) > 0
            get_name(b)
            srvc_ = PSY.get_services(main_comp)
            for ss in srvc_
                srvc_type = typeof(ss)
                srvc_name = PSY.get_name(ss)
                add_service!(
                    b,
                    PSY.get_component(srvc_type, main_sys, srvc_name * "_twin"),
                    main_sys
                    )
            end
        end
        # change scale
        if typeof(b) <: RenewableGen
            PSY.set_base_power!(b, 1.2 * PSY.get_base_power(b))
            PSY.set_base_power!(main_comp, 0.9 * PSY.get_base_power(b))
        end
        if typeof(b) <: PowerLoad
            PSY.set_base_power!(main_comp, 1.2 * PSY.get_base_power(b))
        end
    end

    # conncect two buses: one with a AC line and one with a HVDC line.
    # Consider area 1 and area 1_twin

    # now look at all the buses in area 1
    area_ = PSY.get_component(PSY.Area, main_sys, "1")
    buses_ = [b for b in PSY.get_components(PSY.ACBus, main_sys) if PSY.get_area(b) == area_]

    # get lines for those buses
    br_in_area = []
    br_per_bus = Dict(PSY.get_name(b) => [] for b in buses_)
    br_other_areas = []

    for br in PSY.get_components(PSY.Line, main_sys)
        if PSY.get_from_bus(br) in buses_ || PSY.get_to_bus(br) in buses_
            if !(br in br_in_area)
                push!(br_in_area, br)
            end
            if PSY.get_from_bus(br) in buses_
                if !(PSY.get_name(br) in br_per_bus[PSY.get_name(PSY.get_from_bus(br))])
                    push!(br_per_bus[PSY.get_name(PSY.get_from_bus(br))], PSY.get_name(br))
                end
            end
            if PSY.get_to_bus(br) in buses_
                if !(PSY.get_name(br) in br_per_bus[PSY.get_name(PSY.get_to_bus(br))])
                    push!(br_per_bus[PSY.get_name(PSY.get_to_bus(br))], PSY.get_name(br))
                end
            end
            if (PSY.get_from_bus(br) in buses_ && !(PSY.get_to_bus(br) in buses_)) ||
                (PSY.get_to_bus(br) in buses_ && !(PSY.get_from_bus(br) in buses_))
                if !(br in br_other_areas)
                    push!(br_other_areas, PSY.get_name(br))
                end
            end
        end
    end

    # for now consider Alder (no-leaf) and Avery (leaf)
    new_ACArc = PSY.Arc(
        from = PSY.get_component(PSY.ACBus, main_sys, "Alder"),
        to = PSY.get_component(PSY.ACBus, main_sys, "Alder_twin"),
    )
    PSY.add_component!(main_sys, new_ACArc)

    new_ACLine = PSY.MonitoredLine(
        name = "AC_interconnection",
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        arc = get_component(Arc, main_sys, "Alder -> Alder_twin"),
        r = 0.042,
        x = 0.161,
        b = (from = 0.022, to = 0.022),
        rate = 1.75,
        # For now, not binding
        flow_limits = (from_to = 2.0, to_from = 2.0),
        angle_limits = (min = -1.57079, max = 1.57079),
        services = Vector{Service}[],
        ext = Dict{String, Any}(),
    )
    PSY.add_component!(main_sys, new_ACLine)

    # new_HVDCLine = PSY.TwoTerminalHVDCLine(
    #     name = "HVDC_interconnetion",
    #     available = true,
    #     active_power_flow = 0.0,
    #     arc = get_component(Arc, main_sys, "Alder -> Alder_twin"),
    #     active_power_limits_from = (min = -1000.0, max = 1000.0),
    #     active_power_limits_to = (min = -1000.0, max = 1000.0),
    #     reactive_power_limits_from = (min = -1000.0, max = 1000.0),
    #     reactive_power_limits_to = (min = -1000.0, max = 1000.0),
    #     loss = (l0 = 0.0, l1 = 0.0),
    #     services= Vector{Service}[],
    #     ext = Dict{String, Any}(),
    # )
    # PSY.add_component!(main_sys, new_HVDCLine)

    # serialize

    for bat in get_components(GenericBattery, main_sys)
        set_base_power!(bat, get_base_power(bat)*10)
    end

    for r in get_components(x -> get_prime_mover_type(x) == PrimeMovers.CP, RenewableDispatch, main_sys)
        clear_services!(r)
        remove_component!(main_sys, r)
    end

    for dev in get_components(RenewableFix, main_sys)
        clear_services!(dev)
    end

    for dev in get_components(x -> get_fuel(x) == ThermalFuels.NUCLEAR, ThermalStandard, main_sys)
        clear_services!(dev)
    end

    for dev in get_components(HydroGen, main_sys)
        clear_services!(dev)
    end

    bus_to_change = PSY.get_component(ACBus, main_sys, "Arne_twin")
    PSY.set_bustype!(bus_to_change, PSY.ACBusTypes.PV)

    sys_dict[sys_name] = main_sys
end

# cost perturbation must be the same for each sub-system
for g in get_components(x -> x.prime_mover_type in [PrimeMovers.CT, PrimeMovers.CC], ThermalStandard, sys_dict["RTS_GMLC_DA_sys"])
    old_pwl_array = get_variable(get_operation_cost(g)) |> get_cost
    new_pwl_array = similar(old_pwl_array)
    for (ix, tup) in enumerate(old_pwl_array)
        if ix ∈ [1, length(old_pwl_array)]
            cost_noise = 50.0*rand()
            new_pwl_array[ix] = ((tup[1] + cost_noise), tup[2])
        else
            try_again = true
            while try_again
                cost_noise = 50.0*rand()
                power_noise = 0.01*rand()
                slope_previous = ((tup[1] + cost_noise) - old_pwl_array[ix - 1][1])/((tup[2] - power_noise) - old_pwl_array[ix - 1][2])
                slope_next = (- (tup[1] + cost_noise) + old_pwl_array[ix + 1][1])/(-(tup[2] - power_noise) + old_pwl_array[ix + 1][2])
                new_pwl_array[ix] = ((tup[1] + cost_noise), (tup[2] - power_noise))
                try_again = slope_previous > slope_next
            end
        end
    end
    get_variable(get_operation_cost(g)).cost = new_pwl_array
    rt_gen = get_component(ThermalStandard, sys_dict["RTS_GMLC_RT_sys"], get_name(g))
    get_variable(get_operation_cost(rt_gen)).cost = deepcopy(new_pwl_array)
end

# check values
for g in get_components(x -> x.prime_mover_type in [PrimeMovers.CT, PrimeMovers.CC], ThermalStandard, sys_dict["RTS_GMLC_DA_sys"])
    component_RT = get_component(ThermalStandard, sys_dict["RTS_GMLC_RT_sys"], get_name(g))
    @assert get_variable(get_operation_cost(g)).cost == get_variable(get_operation_cost(component_RT)).cost
end

# modify time series #########################################################

# set service participation

PARTICIPATION = 0.2

# load the systems
DA_sys = sys_dict["RTS_GMLC_DA_sys"]
RT_sys = sys_dict["RTS_GMLC_RT_sys"]

horizon_RT = get_forecast_horizon(RT_sys)
interval_RT = get_forecast_interval(RT_sys)
remove_time_series!(RT_sys, DeterministicSingleTimeSeries)

# remove Flex services
for srvc in PSY.get_components(PSY.Service, DA_sys)
    PSY.get_name(srvc)
    set_max_participation_factor!(srvc, PARTICIPATION)
    if get_name(srvc) in ["Flex_Up", "Flex_Down", "Flex_Up_twin", "Flex_Down_twin"]
        # remove Flex services from DA and RT model
        PSY.remove_component!(DA_sys, srvc)
    end
end

for srvc in PSY.get_components(PSY.Service, RT_sys)
    PSY.get_name(srvc)
    set_max_participation_factor!(srvc, PARTICIPATION)
    if get_name(srvc) in ["Flex_Up", "Flex_Down", "Flex_Up_twin", "Flex_Down_twin"]
        # remove Flex services from DA and RT model
        PSY.remove_component!(RT_sys, srvc)
    end
end

# fix the reserve requirements
services_DA = get_components(Service, DA_sys)
services_DA_names = get_name.(services_DA)

# loop over the different services
for name in services_DA_names
    name
    # Read Reg_Up DA
    service_da = get_component(Service, DA_sys, name)
    time_series_da = get_time_series(SingleTimeSeries, service_da, "requirement").data
    dates_da = timestamp(time_series_da)
    data_da = values(time_series_da)

    # Read Reg_Up RT
    service_rt = get_component(Service, RT_sys, name)
    time_series_rt = get_time_series(SingleTimeSeries, service_rt, "requirement").data
    dates_rt = timestamp(time_series_rt)
    data_rt = values(time_series_rt)

    # Do Zero Order-Hold transform
    rt_data = [
            data_da[div(k - 1, Int(length(data_rt) / length(data_da))) + 1]
            for k in 1:length(data_rt)
        ]

    # check the time series
    for i in eachindex(data_da)
        @assert all(data_da[i] .== rt_data[(i-1)*12+1:12*i])
    end
    new_ts = SingleTimeSeries("requirement", TimeArray(dates_rt, rt_data))
    remove_time_series!(RT_sys, SingleTimeSeries, service_rt, "requirement")
    add_time_series!(RT_sys, service_rt, new_ts)

    # After For Loop
<<<<<<< HEAD

=======

>>>>>>> 63bd8d521979e57749d5b1c4a08fb6938fd09c0b
end
transform_single_time_series!(RT_sys, horizon_RT, interval_RT)

# finally get the HA syste

HA_sys= deepcopy(RT_sys)

# now change the horizon (horizon defined as number of timesteps)
# * timestep resolution is 5 minutes, so 24 timesteps for 2 hours
horizon_rt = get_forecast_horizon(HA_sys)
INTERVAL = Dates.Hour(1)

# clear timeseries in RT and add them back
transform_single_time_series!(HA_sys, horizon_rt, INTERVAL)

##############################################################################
# set up and run the simulation ##############################################

# DC power flow reference solution

# define battery model
storage_model = DeviceModel(
    GenericBattery,
    StorageDispatchWithReserves;
    attributes=Dict(
        "reservation" => false,
        "cycling_limits" => false,
        "energy_target" => false,
        "complete_coverage" => false,
        "regularization" => true
    ),
)

# UC model
template_uc =
    ProblemTemplate(
        # NetworkModel(StandardPTDFModel; PTDF_matrix = PTDF(sys_twin_rts)),
        NetworkModel(DCPPowerModel; use_slacks=true),
    )
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, RenewableFix, FixedOutput)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, Line, StaticBranch)
set_device_model!(template_uc, MonitoredLine, StaticBranch)
set_device_model!(template_uc, Transformer2W, StaticBranchUnbounded)
set_device_model!(template_uc, TapTransformer, StaticBranchUnbounded)
set_device_model!(template_uc, HydroDispatch, FixedOutput)
set_device_model!(template_uc, HydroEnergyReservoir, FixedOutput)
set_device_model!(template_uc, storage_model)
set_service_model!(
    template_uc,
    ServiceModel(VariableReserve{ReserveUp}, RangeReserve; use_slacks = true),
)
set_service_model!(
    template_uc,
    ServiceModel(VariableReserve{ReserveDown}, RangeReserve; use_slacks = true),
)

# HA model (fixing the hydro from the UC)
template_ha = deepcopy(template_uc)
set_device_model!(template_ha, HydroDispatch, HydroDispatchRunOfRiver)
set_device_model!(template_ha, HydroEnergyReservoir, HydroDispatchRunOfRiver)

# ED model
template_ed = deepcopy(template_uc)
set_device_model!(template_ed, ThermalStandard, ThermalStandardDispatch)
set_device_model!(template_ed, HydroDispatch, HydroDispatchRunOfRiver)
set_device_model!(template_ed, HydroEnergyReservoir, HydroDispatchRunOfRiver)

models = SimulationModels(;
    decision_models = [
        DecisionModel(
            template_uc,
            DA_sys;
            name = "UC",
            optimizer = optimizer_with_attributes(
                Xpress.Optimizer,
                "MIPRELSTOP" => 0.01,       # Set the relative mip gap tolerance
            ),
            system_to_file = false,
            initialize_model = true,
            optimizer_solve_log_print = false,
            direct_mode_optimizer = true,
            rebuild_model = false,
            store_variable_names = true,
            calculate_conflict = true,
        ),
        DecisionModel(
            template_ha,
            HA_sys;
            name = "HA",
            optimizer = optimizer_with_attributes(
                Xpress.Optimizer,
                "MIPRELSTOP" => 0.01,       # Set the relative mip gap tolerance
            ),
            system_to_file = false,
            initialize_model = true,
            optimizer_solve_log_print = false,
            check_numerical_bounds = false,
            rebuild_model = false,
            calculate_conflict = true,
            store_variable_names = true,
            #export_pwl_vars = true,
        ),
        DecisionModel(
            template_ed,
            RT_sys;
            name = "ED",
            optimizer = optimizer_with_attributes(Xpress.Optimizer),
            system_to_file = false,
            initialize_model = true,
            optimizer_solve_log_print = false,
            check_numerical_bounds = false,
            rebuild_model = false,
            calculate_conflict = true,
            store_variable_names = true,
            #export_pwl_vars = true,
        ),
    ]
)

# define the different values for the simulation sequence
LBFF = LowerBoundFeedforward(;
    component_type = ThermalStandard,
    source = OnVariable,
    affected_values = [OnVariable],
    )
FVFF_moniterd_line = FixValueFeedforward(;
    component_type = MonitoredLine,
    source = FlowActivePowerVariable,
    affected_values = [FlowActivePowerVariable],
    )
SCFF = SemiContinuousFeedforward(;
    component_type = ThermalStandard,
    source = OnVariable,
    affected_values = [ActivePowerVariable],
    )

ha_simulation_options = Vector{PowerSimulations.AbstractAffectFeedforward}()
ed_simulation_options = Vector{PowerSimulations.AbstractAffectFeedforward}()

# no binding effect on the reserves
push!(ha_simulation_options, LBFF)                  # LB on Thermal
push!(ed_simulation_options, SCFF)

push!(ha_simulation_options, FVFF_moniterd_line)
push!(ed_simulation_options, FVFF_moniterd_line)

sequence = SimulationSequence(;
    models = models,
    feedforwards = Dict(
        "HA" => ha_simulation_options,
        "ED" => ed_simulation_options
    ),
    ini_cond_chronology = InterProblemChronology(),
)

# use different names for saving the solution
sim = Simulation(;
    name = "a1", #ARGS[1],
    steps = 1,
    models = models,
    sequence = sequence,
    initial_time = DateTime("2020-01-01T00:00:00"),
    simulation_folder = mktempdir(".", cleanup = true),
);

build_out = build!(sim; serialize = false)
execute_status = execute!(sim; enable_progress_bar = true);

# temp code

# get the models
models = PSI.get_decision_models(PSI.get_models(sim));
sequence_order = PSI.get_execution_order(PSI.get_sequence(sim));

## -> function 1: get the simulation steps of interest
# it is important to select just the part of the sequence that are not SemiContinuousFeedforward (exclude ED)
model_numbs = [i for i in keys(models)]
ffs = PSI.get_sequence(sim).feedforwards
seq_nums = Vector{Integer}()
for i in keys(models)
    # get name
    name = PSI.get_name(models[i])
    # now check feedforward model
    if name in keys(ffs)
        ff_ = ffs[name]
        select = false
        for j in ff_
            if typeof(j) == PSI.SemiContinuousFeedforward
                select = false
                break
            elseif !(i in seq_nums)
                select = true
            end
        end
        if select
            push!(seq_nums, i)
        end
    end
end

## -> function 2: now check the initial condition between the first step in the
## sequence and the other ones

# get the solution for the reference step (e.g., Day Ahead)
ic_dict = Dict()
ic_ = PSI.get_initial_conditions(models[1]);
ic_dict["names"] = PSY.get_name.(PSI.get_component.(ic_[PSI.ICKey{DeviceStatus, ThermalStandard}("")]))
ic_dict["status"] = PSI.get_condition.(ic_[PSI.ICKey{DeviceStatus, ThermalStandard}("")])
ic_dict["up"] = PSI.get_condition.(ic_[PSI.ICKey{InitialTimeDurationOn, ThermalStandard}("")])
ic_dict["down"] = PSI.get_condition.(ic_[PSI.ICKey{InitialTimeDurationOff, ThermalStandard}("")])

# now check the solution with respect to reference, if needed change values
for i in seq_nums
    # do check to see if the names are in the same order
    curr_names = PSY.get_name.(
        PSI.get_component.(
            PSI.get_initial_conditions(models[i])[PSI.ICKey{DeviceStatus, ThermalStandard}("")]
            )
        )
    @assert all(curr_names .== ic_dict["names"]) "Vector of names mismatch, consider different method"
    for (j, name) in enumerate(ic_dict["names"])
        # logig:
        # if unit is on in ref and on in "i", initial on time must match
        # if unit is off in ref and off in "i", initial off time must match
        # if unit is on in ref and off in "i", initial off time in "i" is set to 999
        # if unit is off in ref and on in "i", initial on time in "i" is set to 999
        ref_status = Int(round(ic_dict["status"][j]))
        curr_status = Int(
                round(
                    PSI.get_condition(
                        PSI.get_initial_conditions(models[i])[PSI.ICKey{DeviceStatus, ThermalStandard}("")][j]
                    )
                )
            )

        if ref_status == 1 && curr_status == 0
            # get initial on time for ref and "i"
            on_ref = ic_dict["up"][j]
            off_i = PSI.get_initial_conditions(
                models[i])[PSI.ICKey{InitialTimeDurationOff, ThermalStandard}("")][j]
            # compare and change if needed
            # println("here1 " * name * " " * string(round(on_ref)) * " " * string(round(PSI.get_condition(off_i))))
            JuMP.fix(off_i.value, 10000)
        elseif ref_status == 0 &&  curr_status == 1
            # repeat as first clause
            off_ref = ic_dict["down"][j]
            on_i = PSI.get_initial_conditions(
                models[i])[PSI.ICKey{InitialTimeDurationOn, ThermalStandard}("")][j]
            # print("here2 " * name * " " * string(round(off_ref)) * " " * string(round(PSI.get_condition(on_i))))
            JuMP.fix(on_i.value, 10000)
        end
    end
end

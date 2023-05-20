using Pkg
Pkg.activate("test")
Pkg.instantiate()
using Revise

using PowerSimulations
using PowerSystems
using PowerSystemCaseBuilder
using InfrastructureSystems
const PSY = PowerSystems
const PSI = PowerSimulations
const PSB = PowerSystemCaseBuilder
using Xpress
using JuMP
using Logging
using Dates
using TimeSeries
using Random
rng = MersenneTwister(1234)
using Interpolations
using Distributions

sys_DA = PSB.build_RTS_GMLC_DA_sys_noTS(; raw_data = PSB.RTS_DIR)
sys_RT = PSB.build_RTS_GMLC_RT_sys_noTS(; raw_data = PSB.RTS_DIR)
sys_RT_HourAhead = PSB.build_RTS_GMLC_RT_sys_noTS(; raw_data = PSB.RTS_DIR)

reserve_hydro = true # use false to remove hydro from the reserve provision devices

area_maps_regup = Dict()
area_maps_regup["1"] = "Reg_Up_R1"
area_maps_regup["2"] = "Reg_Up_R2"
area_maps_regup["3"] = "Reg_Up_R3"

area_maps_regdn = Dict()
area_maps_regdn["1"] = "Reg_Down_R1"
area_maps_regdn["2"] = "Reg_Down_R2"
area_maps_regdn["3"] = "Reg_Down_R3"

area_maps_spin = Dict()
area_maps_spin["1"] = "Spin_Up_R1"
area_maps_spin["2"] = "Spin_Up_R2"
area_maps_spin["3"] = "Spin_Up_R3"

for sys in [sys_DA, sys_RT, sys_RT_HourAhead]
    # Adjust Reserve Provisions
    # Remove Flex Reserves
    res_up = get_component(VariableReserve{ReserveUp}, sys, "Flex_Up")
    if !isnothing(res_up)
        remove_component!(sys, res_up)
    end
    res_dn = get_component(VariableReserve{ReserveDown}, sys, "Flex_Down")
    if !isnothing(res_dn)
        remove_component!(sys, res_dn)
    end
    mult = 1.0
    # Reg Up Split
    reg_reserve_up = get_component(VariableReserve, sys, "Reg_Up")
    set_requirement!(reg_reserve_up, mult * get_requirement(reg_reserve_up))
    for name in ["Reg_Up_R1", "Reg_Up_R2", "Reg_Up_R3"]
        reg_zone = PSY.VariableReserve{ReserveUp}(;
            name = name,
            available = true,
            time_frame = reg_reserve_up.time_frame,
            requirement = reg_reserve_up.requirement / 3.0,
        )
        old_ts = get_time_series(SingleTimeSeries, reg_reserve_up, "requirement")
        add_component!(sys, reg_zone)
        add_time_series!(sys, reg_zone, old_ts)
    end
    remove_component!(sys, reg_reserve_up)
    # Reg Down Split
    reg_reserve_dn = get_component(VariableReserve, sys, "Reg_Down")
    set_requirement!(reg_reserve_dn, mult * get_requirement(reg_reserve_dn))
    for name in ["Reg_Down_R1", "Reg_Down_R2", "Reg_Down_R3"]
        reg_zone = PSY.VariableReserve{ReserveDown}(;
            name = name,
            available = true,
            time_frame = reg_reserve_dn.time_frame,
            requirement = reg_reserve_dn.requirement / 3.0,
        )
        old_ts = get_time_series(SingleTimeSeries, reg_reserve_dn, "requirement")
        add_component!(sys, reg_zone)
        add_time_series!(sys, reg_zone, old_ts)
    end
    remove_component!(sys, reg_reserve_dn)

    spin_reserve_R1 = get_component(VariableReserve, sys, "Spin_Up_R1")
    spin_reserve_R2 = get_component(VariableReserve, sys, "Spin_Up_R2")
    spin_reserve_R3 = get_component(VariableReserve, sys, "Spin_Up_R3")

    for g in get_components(Generator, sys)
        clear_services!(g)
    end
    # Remove Destillate Fuel from sys and update services
    for g in get_components(
        x -> x.prime_mover in [PrimeMovers.CT, PrimeMovers.CC],
        ThermalStandard,
        sys,
    )
        if get_fuel(g) == ThermalFuels.DISTILLATE_FUEL_OIL
            remove_component!(sys, g)
            continue
        end
        g.operation_cost.shut_down = g.operation_cost.start_up / 2.0

        #=
        # Small generators do not participate in reg
        if PSY.get_base_power(g) > 3.0
            clear_services!(g)
            add_service!(g, reg_reserve_dn)
            add_service!(g, reg_reserve_up)
            continue
        end
        =#
        area_name = get_name(get_area(get_bus(g)))
        reg_up = get_component(VariableReserve, sys, area_maps_regup[area_name])
        reg_dn = get_component(VariableReserve, sys, area_maps_regdn[area_name])
        add_service!(g, reg_up, sys)
        add_service!(g, reg_dn, sys)

        # Update costs to avoid degenerate solutions in thermal
        if get_prime_mover(g) == PrimeMovers.CT
            set_status!(g, false)
            set_active_power!(g, 0.0)
            old_pwl_array = get_variable(get_operation_cost(g)) |> get_cost
            new_pwl_array = similar(old_pwl_array)
            for (ix, tup) in enumerate(old_pwl_array)
                if ix ∈ [1, length(old_pwl_array)]
                    cost_noise = 50.0 * rand()
                    new_pwl_array[ix] = ((tup[1] + cost_noise), tup[2])
                else
                    try_again = true
                    while try_again
                        cost_noise = 50.0 * rand()
                        power_noise = 0.01 * rand()
                        slope_previous =
                            ((tup[1] + cost_noise) - old_pwl_array[ix - 1][1]) /
                            ((tup[2] - power_noise) - old_pwl_array[ix - 1][2])
                        slope_next =
                            (-(tup[1] + cost_noise) + old_pwl_array[ix + 1][1]) /
                            (-(tup[2] - power_noise) + old_pwl_array[ix + 1][2])
                        new_pwl_array[ix] = ((tup[1] + cost_noise), (tup[2] - power_noise))
                        try_again = slope_previous > slope_next
                    end
                end
            end
            get_variable(get_operation_cost(g)).cost = new_pwl_array
        end
    end

    for g in get_components(
        x -> !(x.prime_mover in [PrimeMovers.CT, PrimeMovers.CC]),
        ThermalStandard,
        sys,
    )
        get_operation_cost(g).shut_down = get_operation_cost(g).start_up / 2.0
        area_name = get_name(get_area(get_bus(g)))
        reg_up = get_component(VariableReserve, sys, area_maps_regup[area_name])
        reg_dn = get_component(VariableReserve, sys, area_maps_regdn[area_name])
        reg_spin = get_component(VariableReserve, sys, area_maps_spin[area_name])
        if !(get_fuel(g) == ThermalFuels.NUCLEAR)
            add_service!(g, reg_up, sys)
            add_service!(g, reg_dn, sys)
            add_service!(g, reg_spin, sys)
        end
    end

    #=
    for g in get_components(RenewableDispatch, sys)
        set_operation_cost!(g, TwoPartCost(0.0, 0.0))
        area_name = get_name(get_area(get_bus(g)))
        reg_up = get_component(VariableReserve, sys, area_maps_regup[area_name])
        reg_dn = get_component(VariableReserve, sys, area_maps_regdn[area_name])
        reg_spin = get_component(VariableReserve, sys, area_maps_spin[area_name])
        add_service!(g, reg_up, sys)
        add_service!(g, reg_dn, sys)
        add_service!(g, reg_spin, sys)
    end
    =#

    for g in get_components(HydroEnergyReservoir, sys)
        area_name = get_name(get_area(get_bus(g)))
        reg_up = get_component(VariableReserve, sys, area_maps_regup[area_name])
        reg_dn = get_component(VariableReserve, sys, area_maps_regdn[area_name])
        reg_spin = get_component(VariableReserve, sys, area_maps_spin[area_name])
        add_service!(g, reg_up, sys)
        add_service!(g, reg_dn, sys)
        add_service!(g, reg_spin, sys)
    end

    #Remove units that make no sense to include
    names = [
        "114_SYNC_COND_1",
        "314_SYNC_COND_1",
        "313_STORAGE_1",
        "214_SYNC_COND_1",
        "212_CSP_1",
    ]
    for d in get_components(x -> x.name ∈ names, Generator, sys)
        remove_component!(sys, d)
    end
    for br in get_components(DCBranch, sys)
        remove_component!(sys, br)
    end
    for d in get_components(Storage, sys)
        remove_component!(sys, d)
    end

    # Update Ramp Limits
    for d in
        get_components(x -> (occursin(r"STEAM|NUCLEAR", get_name(x))), ThermalStandard, sys)

        #get_fuel(d) == ThermalFuels.COAL && set_ramp_limits!(d, (up = 0.001, down = 0.001))

        #if get_rating(d) < 3.0
        #    set_status!(d, false)
        # clear_services!(d)
        #reserve_hydro && add_service!(d, reg_reserve_up)
        #reserve_hydro && add_service!(d, reg_reserve_dn)
        #add_service!(d, spin_reserve_R1, sys)
        #    set_active_power!(d, 0.0)
        #    continue
        #end
        get_operation_cost(d).shut_down = get_operation_cost(d).start_up / 2.0
        if get_fuel(d) == ThermalFuels.NUCLEAR
            set_ramp_limits!(d, (up = 0.0, down = 0.0))
            set_time_limits!(d, (up = 4380.0, down = 4380.0))
        end
    end

    # Remove bad Hydro
    for d in get_components(HydroDispatch, sys)
        remove_component!(sys, d)
    end

    #=
    for area in get_components(Area, sys)
        if get_name(area) == "1"
            continue
        end
        remove_component!(sys, area)
    end
    for b in get_components(Bus, sys)
        set_area!(b, get_component(Area, sys, "1"))
    end
    =#
end

horizon_DA = 48
interval_DA = Hour(24)
horizon_RT = 24
interval_RT = Minute(5)
horizon_HourAhead = 24
interval_HourAhead = Hour(1)

transform_single_time_series!(sys_DA, horizon_DA, interval_DA)
transform_single_time_series!(sys_RT, horizon_RT, interval_RT)
transform_single_time_series!(sys_RT_HourAhead, horizon_HourAhead, interval_HourAhead)

to_json(sys_DA, "data/sys_DA_1h.json"; force = true)
to_json(sys_RT, "data/sys_RT_5min.json"; force = true)
to_json(sys_RT_HourAhead, "data/sys_RT_HourAhead_2hours.json"; force = true)

##########################################################################################
################################## Here AGC code starts ##################################
##########################################################################################

sys_AGC = deepcopy(sys_RT)
remove_time_series!(sys_AGC, DeterministicSingleTimeSeries)
remove_time_series!(sys_AGC, SingleTimeSeries)

init_time = DateTime("2020-01-01T00:00:00")
final_time = DateTime("2020-12-31T23:59:56")
end_time = DateTime("2020-12-31T23:55:00")

for type in [RenewableFix, ElectricLoad]
    for d in get_components(type, sys_RT)
        @show get_name(d)
        for l in get_time_series_names(SingleTimeSeries, d)
            step_time = Minute(5)
            step_range = Int(Minute(5) / Second(4))
            _dates = range(init_time, final_time; step = Second(4))
            time_series = get_time_series(SingleTimeSeries, d, l)
            total_interp_timeseries = Vector{Float64}(undef, size(_dates)[1])
            current_date = init_time
            i = 0
            while current_date < end_time
                t_stamps = range(current_date; step = Second(4), length = step_range)
                val_init = values(time_series[current_date].data)[1]
                val_next = values(time_series[current_date + step_time].data)[1]
                _vals = range(1, 2; length = step_range)
                interp_vals = LinearInterpolation(1:2, [val_init, val_next])(_vals)
                if type <: ElectricLoad
                    noise = rand(Normal(0.0, 0.025), step_range)
                else
                    noise = rand(Normal(0.0, 0.1), step_range)
                end
                interp_vals .+= noise
                total_interp_timeseries[(i * step_range + 1):((i + 1) * step_range)] =
                    interp_vals
                current_date += step_time
                i = i + 1
            end
            data = TimeArray(_dates, max.(total_interp_timeseries, 0.0))
            ts = SingleTimeSeries(l, data)
            c = get_component(typeof(d), sys_AGC, get_name(d))
            add_time_series!(sys_AGC, c, ts)
        end
    end
end

#=
for g in get_components(ThermalStandard, sys_AGC)
    _date = DateTime("2020-09-01")
    step_time = Hour(1)
    current_date = deepcopy(_date)
    while current_date < DateTime("2020-09-11")
        t_stamps = range(current_date, step = Second(4), length = 900)
        vals = zeros(length(t_stamps))
        forecast = Deterministic("get_rating", TimeArray(t_stamps, vals))
        add_forecast!(sys_AGC, g, forecast)
        current_date += step_time
    end
end

for g in get_components(RenewableDispatch, sys_AGC)
    _date = DateTime("2020-09-01")
    step_time = Hour(1)
    current_date = deepcopy(_date)
    while current_date < DateTime("2020-09-11")
        t_stamps = range(current_date, step = Second(4), length = 900)
        vals = zeros(length(t_stamps))
        forecast = Deterministic("get_rating", TimeArray(t_stamps, vals))
        add_forecast!(sys_AGC, g, forecast)
        current_date += step_time
    end
end
=#

for area in get_components(Area, sys_AGC)
    AGC_service = PSY.AGC(;
        name = "AGC_Area_$(area)",
        available = true,
        bias = 739.0,
        K_p = 2.5 + rand(Normal(0.0, 0.025), 1)[1],
        K_i = max(0.1 + rand(Normal(0.0, 0.00025), 1)[1], 0.001),
        K_d = 0.0,
        delta_t = 4,
        area = get_component(Area, sys_AGC, get_name(area)),
    )

    contributing_devices = Vector{PSY.Device}()
    reg_reserve_up =
        get_component(VariableReserve, sys_AGC, area_maps_regup[get_name(area)])
    for g in get_components(x -> x.bus.area == area, Generator, sys_AGC)
        if has_service(g, reg_reserve_up)
            droop = if isa(g, ThermalStandard)
                0.04 * PSY.get_base_power(g)
            else
                0.05 * PSY.get_base_power(g)
            end
            p_factor = (up = 1.0, dn = 1.0)
            t = RegulationDevice(g; participation_factor = p_factor, droop = droop)
            add_component!(sys_AGC, t)
            push!(contributing_devices, t)
        end
    end

    add_service!(sys_AGC, AGC_service, contributing_devices)
end

for res in get_components(VariableReserve, sys_AGC)
    remove_component!(sys_AGC, res)
end

to_json(sys_AGC, "data/sys_AGC_4sec.json"; force = true)

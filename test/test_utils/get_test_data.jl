time_steps = 1:24

base_dir = string(dirname(dirname(pathof(PowerSimulations))))
DATA_DIR = joinpath(base_dir, "test/test_data")
include(joinpath(DATA_DIR, "data_5bus_pu.jl"))
include(joinpath(DATA_DIR, "data_14bus_pu.jl"))

#Base Systems
nodes = nodes5()
c_sys5 = System(
    nodes,
    thermal_generators5(nodes),
    loads5(nodes),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5))
        add_forecast!(
            c_sys5,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
end

nodes = nodes5()
c_sys5_ml = System(
    nodes,
    thermal_generators5(nodes),
    loads5(nodes),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_ml))
        add_forecast!(
            c_sys5_ml,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
end

nodes = nodes14()
c_sys14 = System(
    nodes,
    thermal_generators14(nodes),
    loads14(nodes),
    branches14(nodes),
    nothing,
    100.0,
    nothing,
    nothing,
)
for (ix, l) in enumerate(get_components(PowerLoad, c_sys14))
    add_forecast!(c_sys14, l, Deterministic("get_maxactivepower", timeseries_DA14[ix]))
end

PTDF5 = PTDF(c_sys5);
PTDF14 = PTDF(c_sys14);

#System with Renewable Energy
nodes = nodes5()
c_sys5_re = System(
    nodes,
    vcat(thermal_generators5(nodes), renewable_generators5(nodes)),
    loads5(nodes),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_re))
        add_forecast!(
            c_sys5_re,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
    for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_re))
        add_forecast!(c_sys5_re, r, Deterministic("get_rating", ren_timeseries_DA[t][ix]))
    end
end

nodes = nodes5()
c_sys5_re_only = System(
    nodes,
    renewable_generators5(nodes),
    loads5(nodes),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_re_only))
        add_forecast!(
            c_sys5_re_only,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
    for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_re_only))
        add_forecast!(
            c_sys5_re_only,
            r,
            Deterministic("get_rating", ren_timeseries_DA[t][ix]),
        )
    end
end

nodes = nodes5()
# System with HydroPower Energy
c_sys5_hy = System(
    nodes,
    vcat(thermal_generators5(nodes), hydro_generators5(nodes)[1]),
    loads5(nodes),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_hy))
        add_forecast!(
            c_sys5_hy,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
    for (ix, h) in enumerate(get_components(HydroGen, c_sys5_hy))
        add_forecast!(c_sys5_hy, h, Deterministic("get_rating", hydro_timeseries_DA[t][ix]))
    end
end

nodes = nodes5()
c_sys5_hyd = System(
    nodes,
    vcat(thermal_generators5(nodes), hydro_generators5(nodes)[2]),
    loads5(nodes),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_hyd))
        add_forecast!(
            c_sys5_hyd,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
    for (ix, h) in enumerate(get_components(HydroGen, c_sys5_hyd))
        add_forecast!(
            c_sys5_hyd,
            h,
            Deterministic("get_rating", hydro_timeseries_DA[t][ix]),
        )
    end
    for (ix, h) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hyd))
        add_forecast!(
            c_sys5_hyd,
            h,
            Deterministic("get_storage_capacity", hydro_timeseries_DA[t][ix]),
        )
    end
    for (ix, h) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hyd))
        add_forecast!(
            c_sys5_hyd,
            h,
            Deterministic("get_inflow", hydro_timeseries_DA[t][ix] .* 0.8),
        )
    end
end

#System with Storage Device
nodes = nodes5()
c_sys5_bat = System(
    nodes,
    vcat(thermal_generators5(nodes), renewable_generators5(nodes)),
    loads5(nodes),
    branches5(nodes),
    battery5(nodes),
    100.0,
    nothing,
    nothing,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_bat))
        add_forecast!(
            c_sys5_bat,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
end

#System with Interruptible Load
nodes = nodes5()
c_sys5_il = System(
    nodes,
    thermal_generators5(nodes),
    vcat(loads5(nodes), interruptible(nodes)),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_il))
        add_forecast!(
            c_sys5_il,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
    for (ix, i) in enumerate(get_components(InterruptibleLoad, c_sys5_il))
        add_forecast!(
            c_sys5_il,
            i,
            Deterministic("get_maxactivepower", Iload_timeseries_DA[t][ix]),
        )
    end
end

#Systems with HVDC data in the branches
nodes = nodes5()
c_sys5_dc = System(
    nodes,
    vcat(thermal_generators5(nodes), renewable_generators5(nodes)),
    loads5(nodes),
    branches5_dc(nodes),
    nothing,
    100.0,
    nothing,
    nothing,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_dc))
        add_forecast!(
            c_sys5_dc,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
    for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_dc))
        add_forecast!(c_sys5_dc, r, Deterministic("get_rating", ren_timeseries_DA[t][ix]))
    end
end

nodes = nodes14()
c_sys14_dc = System(
    nodes,
    thermal_generators14(nodes),
    loads14(nodes),
    branches14_dc(nodes),
    nothing,
    100.0,
    nothing,
    nothing,
)
for (ix, l) in enumerate(get_components(PowerLoad, c_sys14_dc))
    add_forecast!(c_sys14_dc, l, Deterministic("get_maxactivepower", timeseries_DA14[ix]))
end

PTDF5_dc = PTDF(c_sys5_dc);
PTDF14_dc = PTDF(c_sys14_dc);

# System to test UC Forms
#Park City and Sundance Have non-binding Ramp Limitst at an Hourly Resolution
# Solitude, Sundance and Brighton have binding time_up constraints.
# Solitude and Brighton have binding time_dn constraints.
# Sundance has non-binding Time Down constraint at an Hourly Resolution
# Alta, Park City and Brighton start at 0.
thermal_generators5_uc_testing(nodes5) = [
    ThermalStandard(
        "Alta",
        true,
        true,
        nodes5[1],
        0.0,
        0.0,
        0.5,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.2, max = 0.40),
        (min = -0.30, max = 0.30),
        nothing,
        nothing,
        ThreePartCost((0.0, 1400.0), 0.0, 4.0, 2.0),
    ),
    ThermalStandard(
        "Park City",
        true,
        true,
        nodes5[1],
        0.0,
        0.0,
        2.2125,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.65, max = 1.70),
        (min = -1.275, max = 1.275),
        (up = 0.02, down = 0.02),
        nothing,
        ThreePartCost((0.0, 1500.0), 0.0, 1.5, 0.75),
    ),
    ThermalStandard(
        "Solitude",
        true,
        true,
        nodes5[3],
        2.7,
        0.00,
        5.20,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 1.0, max = 5.20),
        (min = -3.90, max = 3.90),
        (up = 0.0012, down = 0.0012),
        (up = 5.0, down = 3.0),
        ThreePartCost((0.0, 3000.0), 0.0, 3.0, 1.5),
    ),
    ThermalStandard(
        "Sundance",
        true,
        true,
        nodes5[4],
        0.0,
        0.00,
        2.5,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 1.0, max = 2.0),
        (min = -1.5, max = 1.5),
        (up = 0.015, down = 0.015),
        (up = 2.0, down = 1.0),
        ThreePartCost((0.0, 4000.0), 0.0, 4.0, 2.0),
    ),
    ThermalStandard(
        "Brighton",
        true,
        true,
        nodes5[5],
        6.0,
        0.0,
        7.5,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 3.0, max = 6.0),
        (min = -4.50, max = 4.50),
        (up = 0.0015, down = 0.0015),
        (up = 5.0, down = 3.0),
        ThreePartCost((0.0, 1000.0), 0.0, 1.5, 0.75),
    ),
];
nodes = nodes5()
c_sys5_uc = System(
    nodes,
    thermal_generators5_uc_testing(nodes),
    loads5(nodes),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing;
    time_series_in_memory = true,
);
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_uc))
        add_forecast!(
            c_sys5_uc,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
    for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_uc))
        add_forecast!(c_sys5_uc, r, Deterministic("get_rating", ren_timeseries_DA[t][ix]))
    end
    for (ix, i) in enumerate(get_components(InterruptibleLoad, c_sys5_uc))
        add_forecast!(
            c_sys5_uc,
            i,
            Deterministic("get_maxactivepower", Iload_timeseries_DA[t][ix]),
        )
    end
end

c_sys5_ed = System(
    nodes,
    vcat(thermal_generators5_uc_testing(nodes), renewable_generators5(nodes)),
    vcat(loads5(nodes), interruptible(nodes)),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing;
    time_series_in_memory = true,
);

for t in 1:2 # loop over days
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_ed))
        ta = load_timeseries_DA[t][ix]
        for i in 1:length(ta) # loop over hours
            ini_time = timestamp(ta[i]) #get the hour
            data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
            add_forecast!(c_sys5_ed, l, Deterministic("get_maxactivepower", data))
        end
    end
end
for t in 1:2
    for (ix, l) in enumerate(get_components(RenewableGen, c_sys5_ed))
        ta = load_timeseries_DA[t][ix]
        for i in 1:length(ta) # loop over hours
            ini_time = timestamp(ta[i]) #get the hour
            data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
            add_forecast!(c_sys5_ed, l, Deterministic("get_rating", data))
        end
    end
end
for t in 1:2
    for (ix, l) in enumerate(get_components(InterruptibleLoad, c_sys5_ed))
        ta = load_timeseries_DA[t][ix]
        for i in 1:length(ta) # loop over hours
            ini_time = timestamp(ta[i]) #get the hour
            data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
            add_forecast!(c_sys5_ed, l, Deterministic("get_maxactivepower", data))
        end
    end
end

reserve_uc = reserve5(get_components(ThermalStandard, c_sys5_uc))
add_service!(c_sys5_uc, reserve_uc[1], get_components(ThermalStandard, c_sys5_uc))
add_service!(
    c_sys5_uc,
    reserve_uc[2],
    [collect(get_components(ThermalStandard, c_sys5_uc))[end]],
)
add_service!(c_sys5_uc, reserve_uc[3], get_components(ThermalStandard, c_sys5_uc))
add_service!(c_sys5_uc, reserve_uc[4], get_components(ThermalStandard, c_sys5_uc))
for t in 1:2, (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_uc))
    add_forecast!(c_sys5_uc, serv, Deterministic("get_requirement", Reserve_ts[t]))
end

reserve_bat = reserve5_re(get_components(RenewableDispatch, c_sys5_re))
add_service!(c_sys5_bat, reserve_bat[1], get_components(GenericBattery, c_sys5_bat))
add_service!(c_sys5_bat, reserve_bat[2], get_components(GenericBattery, c_sys5_bat))
add_service!(c_sys5_bat, reserve_bat[3], get_components(GenericBattery, c_sys5_bat))
for t in 1:2, (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_bat))
    add_forecast!(c_sys5_bat, serv, Deterministic("get_requirement", Reserve_ts[t]))
end

reserve_re = reserve5_re(get_components(RenewableDispatch, c_sys5_re))
add_service!(c_sys5_re, reserve_re[1], get_components(RenewableDispatch, c_sys5_re))
add_service!(
    c_sys5_re,
    reserve_re[2],
    [collect(get_components(RenewableDispatch, c_sys5_re))[end]],
)
add_service!(c_sys5_re, reserve_re[3], get_components(RenewableDispatch, c_sys5_re))
for t in 1:2, (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_re))
    add_forecast!(c_sys5_re, serv, Deterministic("get_requirement", Reserve_ts[t]))
end

reserve_hy = reserve5_hy(get_components(HydroEnergyReservoir, c_sys5_hyd))
add_service!(c_sys5_hyd, reserve_hy[1], get_components(HydroEnergyReservoir, c_sys5_hyd))
add_service!(
    c_sys5_hyd,
    reserve_hy[2],
    [collect(get_components(HydroEnergyReservoir, c_sys5_hyd))[end]],
)
add_service!(c_sys5_hyd, reserve_hy[3], get_components(HydroEnergyReservoir, c_sys5_hyd))
for t in 1:2, (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_hyd))
    add_forecast!(c_sys5_hyd, serv, Deterministic("get_requirement", Reserve_ts[t]))
end

reserve_il = reserve5_il(get_components(InterruptibleLoad, c_sys5_il))
add_service!(c_sys5_il, reserve_il[1], get_components(InterruptibleLoad, c_sys5_il))
add_service!(
    c_sys5_il,
    reserve_il[2],
    [collect(get_components(InterruptibleLoad, c_sys5_il))[end]],
)
add_service!(c_sys5_il, reserve_il[3], get_components(InterruptibleLoad, c_sys5_il))
for t in 1:2, (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_il))
    add_forecast!(c_sys5_il, serv, Deterministic("get_requirement", Reserve_ts[t]))
end

function build_init(gens, data)
    init = Vector{InitialCondition}(undef, length(collect(gens)))
    for (ix, g) in enumerate(gens)
        init[ix] = InitialCondition(
            g,
            PSI.UpdateRef{JuMP.VariableRef}(PSI.ACTIVE_POWER),
            data[ix],
            TimeStatusChange,
        )
    end
    return init
end

c_sys5_hy_uc = System(
    nodes,
    vcat(
        thermal_generators5_uc_testing(nodes),
        hydro_generators5(nodes),
        renewable_generators5(nodes),
    ),
    loads5(nodes),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing;
    time_series_in_memory = true,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_hy_uc))
        add_forecast!(
            c_sys5_hy_uc,
            l,
            Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]),
        )
    end
    for (ix, h) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_uc))
        add_forecast!(
            c_sys5_hy_uc,
            h,
            Deterministic("get_rating", hydro_timeseries_DA[t][ix]),
        )
    end
    for (ix, h) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_uc))
        add_forecast!(
            c_sys5_hy_uc,
            h,
            Deterministic("get_storage_capacity", hydro_timeseries_DA[t][ix]),
        )
    end
    for (ix, h) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_uc))
        add_forecast!(
            c_sys5_hy_uc,
            h,
            Deterministic("get_inflow", hydro_timeseries_DA[t][ix] .* 0.8),
        )
    end
    for (ix, h) in enumerate(get_components(HydroDispatch, c_sys5_hy_uc))
        add_forecast!(
            c_sys5_hy_uc,
            h,
            Deterministic("get_rating", hydro_timeseries_DA[t][ix]),
        )
    end
    for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_hy_uc))
        add_forecast!(
            c_sys5_hy_uc,
            r,
            Deterministic("get_rating", ren_timeseries_DA[t][ix]),
        )
    end
    for (ix, i) in enumerate(get_components(InterruptibleLoad, c_sys5_hy_uc))
        add_forecast!(
            c_sys5_hy_uc,
            i,
            Deterministic("get_maxactivepower", Iload_timeseries_DA[t][ix]),
        )
    end
end

c_sys5_hy_ed = System(
    nodes,
    vcat(
        thermal_generators5_uc_testing(nodes),
        hydro_generators5(nodes),
        renewable_generators5(nodes),
    ),
    vcat(loads5(nodes), interruptible(nodes)),
    branches5(nodes),
    nothing,
    100.0,
    nothing,
    nothing;
    time_series_in_memory = true,
)
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_hy_ed))
        ta = load_timeseries_DA[t][ix]
        for i in 1:length(ta)
            ini_time = timestamp(ta[i])
            data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1]))
            add_forecast!(c_sys5_hy_ed, l, Deterministic("get_maxactivepower", data))
        end
    end
    for (ix, l) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_ed))
        ta = hydro_timeseries_DA[t][ix]
        for i in 1:length(ta)
            ini_time = timestamp(ta[i])
            data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
            add_forecast!(c_sys5_hy_ed, l, Deterministic("get_rating", data))
        end
    end
    for (ix, l) in enumerate(get_components(RenewableGen, c_sys5_hy_ed))
        ta = load_timeseries_DA[t][ix]
        for i in 1:length(ta)
            ini_time = timestamp(ta[i])
            data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1]))
            add_forecast!(c_sys5_hy_ed, l, Deterministic("get_rating", data))
        end
    end
    for (ix, l) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_ed))
        ta = hydro_timeseries_DA[t][ix]
        for i in 1:length(ta)
            ini_time = timestamp(ta[i])
            data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
            add_forecast!(c_sys5_hy_ed, l, Deterministic("get_storage_capacity", data))
        end
    end
    for (ix, l) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_ed))
        ta = hydro_timeseries_DA[t][ix]
        for i in 1:length(ta)
            ini_time = timestamp(ta[i])
            data = when(hydro_timeseries_RT[t][ix] .* 0.8, hour, hour(ini_time[1]))
            add_forecast!(c_sys5_hy_ed, l, Deterministic("get_inflow", data))
        end
    end
    for (ix, l) in enumerate(get_components(InterruptibleLoad, c_sys5_hy_ed))
        ta = load_timeseries_DA[t][ix]
        for i in 1:length(ta)
            ini_time = timestamp(ta[i])
            data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1]))
            add_forecast!(c_sys5_hy_ed, l, Deterministic("get_maxactivepower", data))
        end
    end
    for (ix, l) in enumerate(get_components(HydroDispatch, c_sys5_hy_ed))
        ta = hydro_timeseries_DA[t][ix]
        for i in 1:length(ta)
            ini_time = timestamp(ta[i])
            data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
            add_forecast!(c_sys5_hy_ed, l, Deterministic("get_rating", data))
        end
    end
end

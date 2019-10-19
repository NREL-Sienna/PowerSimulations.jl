time_steps = 1:24

base_dir = string(dirname(dirname(pathof(PowerSystems))))
DATA_DIR = joinpath(base_dir, "data")
include(joinpath(base_dir, "data/data_5bus_pu.jl"))
include(joinpath(base_dir, "data/data_14bus_pu.jl"))

#Base Systems
c_sys5 = System(nodes5, thermal_generators5, loads5, branches5, nothing, 100.0, reserve5, nothing)
for t in 1:2
    for (ix, l) in enumerate(loads5)
        add_forecast!(c_sys5, deepcopy(l), Deterministic("maxactivepower", load_forecast_DA[t][ix]))
    end
end

c_sys14 = System(nodes14, thermal_generators14, loads14, branches14, nothing, 100.0, nothing, nothing)
for (ix, l) in enumerate(loads14)
    add_forecast!(c_sys14, deepcopy(l), Deterministic("maxactivepower", forecast_DA14[ix]))
end

PTDF5 = PTDF(branches5, nodes5);
PTDF14 = PTDF(branches14, nodes14);

#System with Renewable Energy
c_sys5_re = System(nodes5, vcat(thermal_generators5, renewable_generators5), loads5, branches5, nothing, 100.0, reserve5, nothing)
for t in 1:2
    for (ix, l) in enumerate(loads5)
        add_forecast!(c_sys5_re, deepcopy(l), Deterministic("maxactivepower", load_forecast_DA[t][ix]))
    end
    for (ix, r) in enumerate(renewable_generators5)
        add_forecast!(c_sys5_re, deepcopy(r), Deterministic("rating", ren_forecast_DA[t][ix]))
    end
end

c_sys5_re_only = System(nodes5, renewable_generators5, loads5, branches5, nothing, 100.0, reserve5, nothing)
for t in 1:2
    for (ix, r) in enumerate(renewable_generators5)
        add_forecast!(c_sys5_re_only, deepcopy(r), Deterministic("rating", ren_forecast_DA[t][ix]))
    end
end

#System with HydroPower Energy
c_sys5_hy = System(nodes5, vcat(thermal_generators5, hydro_generators5[1]), loads5, branches5, nothing, 100.0, reserve5, nothing)
for t in 1:2
    for (ix, l) in enumerate(loads5)
        add_forecast!(c_sys5_hy, deepcopy(l), Deterministic("maxactivepower", load_forecast_DA[t][ix]))
    end
    for (ix, h) in enumerate([hydro_generators5[1]])
        add_forecast!(c_sys5_hy, deepcopy(h), Deterministic("rating", hydro_forecast_DA[t][ix]))
    end
end

#System with Storage Device
c_sys5_bat = System(nodes5, thermal_generators5, loads5, branches5, battery5, 100.0, reserve5, nothing)
for t in 1:2
    for (ix, l) in enumerate(loads5)
        add_forecast!(c_sys5, deepcopy(l), Deterministic("maxactivepower", load_forecast_DA[t][ix]))
    end
end

#System with Interruptible Load
c_sys5_il = System(nodes5, thermal_generators5, vcat(loads5, interruptible), branches5, nothing, 100.0, reserve5, nothing)
for t in 1:2
    for (ix, l) in enumerate(loads5)
        add_forecast!(c_sys5_il, deepcopy(l), Deterministic("maxactivepower", load_forecast_DA[t][ix]))
    end
    for (ix, i) in enumerate(interruptible)
        add_forecast!(c_sys5_il, deepcopy(i), Deterministic("maxactivepower", Iload_forecast[t][ix]))
    end
end

#Systems with HVDC data in the branches
c_sys5_dc = System(nodes5, vcat(thermal_generators5, renewable_generators5), loads5, branches5_dc, nothing, 100.0, reserve5, nothing)
for t in 1:2
    for (ix, l) in enumerate(loads5)
        add_forecast!(c_sys5_dc, deepcopy(l), Deterministic("maxactivepower", load_forecast_DA[t][ix]))
    end
    for (ix, r) in enumerate(renewable_generators5)
        add_forecast!(c_sys5_dc, deepcopy(r), Deterministic("rating", ren_forecast_DA[t][ix]))
    end
end

c_sys14_dc = System(nodes14, thermal_generators14, loads14, branches14_dc, nothing, 100.0, reserve5, nothing)
for (ix, l) in enumerate(loads14)
    add_forecast!(c_sys14, deepcopy(l), Deterministic("maxactivepower", forecast_DA14[ix]))
end

b_ac_5 = collect(get_components(ACBranch, c_sys5_dc))
PTDF5_dc = PTDF(b_ac_5, nodes5);
b_ac_14 = collect(get_components(ACBranch, c_sys14_dc))
PTDF14_dc = PTDF(b_ac_14, nodes14);

# System to test UC Forms
#Park City and Sundance Have non-binding Ramp Limitst at an Hourly Resolution
# Solitude, Sundance and Brighton have binding time_up constraints.
# Solitude and Brighton have binding time_dn constraints.
# Sundance has non-binding Time Down constraint at an Hourly Resolution
# Alta, Park City and Brighton start at 0.
thermal_generators5_uc_testing = [ThermalStandard("Alta", true, nodes5[1], 0.0, 0.0,
           TechThermal(0.5, PowerSystems.ST, PowerSystems.COAL, (min=0.2, max=0.40),  (min = -0.30, max = 0.30), nothing, nothing),
           ThreePartCost((0.0, 1400.0), 0.0, 4.0, 2.0)
           ),
           ThermalStandard("Park City", true, nodes5[1], 0.0, 0.0,
               TechThermal(2.2125, PowerSystems.ST, PowerSystems.COAL, (min=0.65, max=1.70), (min =-1.275, max=1.275), (up=0.02, down=0.02), nothing),
               ThreePartCost((0.0, 1500.0), 0.0, 1.5, 0.75)
           ),
           ThermalStandard("Solitude", true, nodes5[3], 2.7, 0.00,
               TechThermal(5.20, PowerSystems.ST, PowerSystems.COAL, (min=1.0, max=5.20), (min =-3.90, max=3.90), (up=0.0012, down=0.0012), (up=5.0, down=3.0)),
               ThreePartCost((0.0, 3000.0), 0.0, 3.0, 1.5)
           ),
           ThermalStandard("Sundance", true, nodes5[4], 0.0, 0.00,
               TechThermal(2.5, PowerSystems.ST, PowerSystems.COAL, (min=1.0, max=2.0), (min =-1.5, max=1.5), (up=0.015, down=0.015), (up=2.0, down=1.0)),
               ThreePartCost((0.0, 4000.0), 0.0, 4.0, 2.0)
           ),
           ThermalStandard("Brighton", true, nodes5[5], 6.0, 0.0,
               TechThermal(7.5, PowerSystems.ST, PowerSystems.COAL, (min=3.0, max=6.0), (min =-4.50, max=4.50), (up=0.0015, down=0.0015), (up=5.0, down=3.0)),
               ThreePartCost((0.0, 1000.0), 0.0, 1.5, 0.75)
           )];
c_sys5_uc = System(nodes5, thermal_generators5_uc_testing, loads5, branches5, nothing, 100.0, reserve5, nothing);

for t in 1:2
    for (ix, l) in enumerate(loads5)
        add_forecast!(c_sys5_uc, l, Deterministic("maxactivepower", load_forecast_DA[t][ix]))
    end
end

function build_init(gens, data)
    init = Vector{InitialCondition}(undef, length(collect(gens)))
    for (ix,g) in enumerate(gens)
        init[ix] = InitialCondition(g,
                    PSI.UpdateRef{Device}(Symbol("P_$(typeof(g))")),
                    data[ix],TimeStatusChange)
    end
    return init
end

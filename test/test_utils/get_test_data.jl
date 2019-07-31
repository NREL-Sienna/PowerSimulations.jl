time_steps = 1:24

base_dir = string(dirname(dirname(pathof(PowerSystems))));
DATA_DIR = joinpath(base_dir, "data")
include(joinpath(base_dir, "data/data_5bus_pu.jl"));
include(joinpath(base_dir, "data/data_14bus_pu.jl"))

#Base Systems
c_sys5 = PSY.System(nodes5, thermal_generators5, loads5, branches5, nothing, 100.0, nothing, nothing, nothing);
add_forecasts!(c_sys5, load_forecast_DA)
c_sys14 = PSY.System(nodes14, thermal_generators14, loads14, branches14, nothing, 100.0, nothing, nothing, nothing);
add_forecasts!(c_sys14, forecast_DA14)
PTDF5 = PSY.PTDF(branches5, nodes5);
PTDF14 = PSY.PTDF(branches14, nodes14);

#System with Renewable Energy
c_sys5_re = PSY.System(nodes5, vcat(thermal_generators5, renewable_generators5), loads5, branches5, nothing, 100.0, nothing, nothing, nothing);
add_forecasts!(c_sys5_re, ren_forecast_DA)
add_forecasts!(c_sys5_re, load_forecast_DA)

c_sys5_re_only = PSY.System(nodes5, renewable_generators5, loads5, branches5, nothing, 100.0, nothing, nothing, nothing);
add_forecasts!(c_sys5_re_only, load_forecast_DA)
add_forecasts!(c_sys5_re_only, ren_forecast_DA)

#System with HydroPower Energy
c_sys5_hy = PSY.System(nodes5, vcat(thermal_generators5, hydro_generators5[1]), loads5, branches5, nothing, 100.0, nothing, nothing, nothing);
add_forecasts!(c_sys5_hy, [hydro_forecast_DA[1]])
add_forecasts!(c_sys5_hy, load_forecast_DA)

#System with Storage Device
c_sys5_bat = PSY.System(nodes5, thermal_generators5, loads5, branches5, battery5, 100.0, nothing, nothing, nothing);
add_forecasts!(c_sys5_bat, load_forecast_DA)

#System with Interruptible Load
c_sys5_il = PSY.System(nodes5, thermal_generators5, vcat(loads5, interruptible), branches5, nothing, 100.0, nothing, nothing, nothing);
add_forecasts!(c_sys5_il, load_forecast_DA)
add_forecasts!(c_sys5_il, Iload_forecast)

#Systems with HVDC data in the branches
c_sys5_dc = PSY.System(nodes5, vcat(thermal_generators5, renewable_generators5), loads5, branches5_dc, nothing, 100.0, nothing, nothing, nothing);
c_sys14_dc = PSY.System(nodes14, thermal_generators14, loads14, branches14_dc, nothing, 100.0, nothing, nothing, nothing);
add_forecasts!(c_sys5_dc, load_forecast_DA)
add_forecasts!(c_sys5_dc, ren_forecast_DA)
add_forecasts!(c_sys14_dc, forecast_DA14)
b_ac_5 = collect(get_components(PSY.ACBranch, c_sys5_dc))
PTDF5_dc = PSY.PTDF(b_ac_5, nodes5);
b_ac_14 = collect(get_components(PSY.ACBranch, c_sys14_dc))
PTDF14_dc = PSY.PTDF(b_ac_14, nodes14);

# System to test UC Formulations
#Park City and Sundance Have non-binding Ramp Limitst at an Hourly Resolution
# Solitude, Sundance and Brighton have binding time_up constraints.
# Solitude and Brighton have binding time_dn constraints.
# Sundance has non-binding Time Down constraint at an Hourly Resolution
# Alta, Park City and Brighton start at 0.
thermal_generators5_uc_testing = [ThermalStandard("Alta", true, nodes5[1],
                        TechThermal(0.5, 0.0, (min=0.20, max=0.40), 0.010, (min = -0.30, max = 0.30), nothing, nothing),
                        ThreePartCost((0.0, 1400.0), 0.0, 4.0, 2.0)
                        ),
                        ThermalStandard("Park City", true, nodes5[1],
                            TechThermal(2.2125, 0.0, (min=0.75, max=1.70), 0.20, (min =-1.275, max=1.275), (up=0.02, down=0.02), nothing),
                            ThreePartCost((0.0, 1500.0), 0.0, 1.5, 0.75)
                        ),
                        ThermalStandard("Solitude", true, nodes5[3],
                            TechThermal(6.5, 5.20, (min=2.5, max=5.20), 1.00, (min =-3.90, max=3.90), (up=0.0012, down=0.0012), (up=5.0, down=3.0)),
                            ThreePartCost((0.0, 3000.0), 0.0, 3.0, 1.5)
                        ),
                        ThermalStandard("Sundance", true, nodes5[4],
                            TechThermal(2.5, 0.0, (min=1.0, max=2.0), 0.40, (min =-1.5, max=1.5), (up=0.015, down=0.015), (up=2.0, down=1.0)),
                            ThreePartCost((0.0, 4000.0), 0.0, 4.0, 2.0)
                        ),
                        ThermalStandard("Brighton", true, nodes5[5],
                            TechThermal(7.5, 6.0, (min=4.0, max=6.0), 1.50, (min =-4.50, max=4.50), (up=0.0015, down=0.0015), (up=5.0, down=3.0)),
                            ThreePartCost((0.0, 1000.0), 0.0, 1.5, 0.75)
                        )];
c_sys5_uc = PSY.System(nodes5, thermal_generators5_uc_testing, loads5, branches5, nothing, 100.0, nothing, nothing, nothing);
add_forecasts!(c_sys5_uc, load_forecast_DA)

#= RTS Data
RTS_GMLC_DIR = joinpath(DATA_DIR, "RTS_GMLC")
const DESCRIPTORS = joinpath(RTS_GMLC_DIR, "user_descriptors.yaml")

function create_rts_system(forecast_resolution=Dates.Hour(1))
    data = PSY.PowerSystemRaw(RTS_GMLC_DIR, 100.0, DESCRIPTORS)
    return PSY.System(data; forecast_resolution=forecast_resolution)
end
c_rts = create_rts_system();
=#
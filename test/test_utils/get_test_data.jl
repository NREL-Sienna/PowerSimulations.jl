time_steps = 1:24

base_dir = string(dirname(dirname(pathof(PowerSystems))));
DATA_DIR = joinpath(base_dir, "data")
include(joinpath(base_dir,"data/data_5bus_pu.jl"));
include(joinpath(base_dir,"data/data_14bus_pu.jl"))
bus_numbers5 = sort([b.number for b in nodes5])
bus_numbers14 = sort([b.number for b in nodes14]);

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

#System with Storage Device
c_sys5_bat = PSY.System(nodes5, thermal_generators5, loads5, branches5, battery5, 100.0, nothing, nothing, nothing);
add_forecasts!(c_sys5_bat, load_forecast_DA)

#System with Interruptible Load
c_sys5_il = PSY.System(nodes5, thermal_generators5, vcat(loads5,interruptible), branches5, nothing, 100.0, nothing, nothing, nothing);
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

#= RTS Data
RTS_GMLC_DIR = joinpath(DATA_DIR, "RTS_GMLC")
const DESCRIPTORS = joinpath(RTS_GMLC_DIR, "user_descriptors.yaml")

function create_rts_system(forecast_resolution=Dates.Hour(1))
    data = PSY.PowerSystemRaw(RTS_GMLC_DIR, 100.0, DESCRIPTORS)
    return PSY.System(data; forecast_resolution=forecast_resolution)
end
c_rts = create_rts_system();
=#
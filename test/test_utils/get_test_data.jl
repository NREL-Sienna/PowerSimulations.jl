time_steps = 1:24

base_dir = string(dirname(dirname(pathof(PowerSystems))));
DATA_DIR = joinpath(base_dir, "data")
include(joinpath(base_dir,"data/data_5bus_pu.jl"));
include(joinpath(base_dir,"data/data_14bus_pu.jl"))

#Base Systems
sys5 = PSY._System(nodes5, thermal_generators5, loads5, branches5, nothing,  100.0, forecasts5, nothing, nothing);
sys14 = PSY._System(nodes14, thermal_generators14, loads14, branches14, nothing,  100.0, forecasts14, nothing, nothing);
c_sys5 = PSY.System(sys5)
c_sys14 = PSY.System(sys14)
PTDF5 = PSY.PTDF(branches5, nodes5);
PTDF14 = PSY.PTDF(branches14, nodes14);
buses5 = PSY.get_components(PSY.Bus, c_sys5)
buses14 = PSY.get_components(PSY.Bus, c_sys14)

#System with Renewable Energy
sys5_re = PSY._System(nodes5, vcat(thermal_generators5, renewable_generators5), loads5, branches5, nothing,  100.0, forecasts5, nothing, nothing);
c_sys5_re = PSY.System(sys5_re)

#System with Storage Device
sys5_bat = PSY._System(nodes5, thermal_generators5, loads5, branches5, battery5,  100.0, forecasts5, nothing, nothing);
c_sys5_bat = PSY.System(sys5_bat)

# RTS Data
#RTS_GMLC_DIR = joinpath(DATA_DIR, "RTS_GMLC")
#cdm_dict = PSY.csv2ps_dict(RTS_GMLC_DIR, 100.0);
#sys_rts = PSY._System(cdm_dict);
#c_rts = PSY.System(sys_rts);

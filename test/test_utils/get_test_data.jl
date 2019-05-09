time_range = 1:24

base_dir = string(dirname(dirname(pathof(PowerSystems))));
DATA_DIR = joinpath(base_dir, "data")
include(joinpath(base_dir,"data/data_5bus_pu.jl"));
include(joinpath(base_dir,"data/data_14bus_pu.jl"))
bus_numbers5 = [b.number for b in nodes5]
bus_numbers14 = [b.number for b in nodes14];

#Base Systems
sys5 = PSY.System(nodes5, thermal_generators5, loads5, branches5, nothing,  100.0, forecasts5, nothing, nothing);
sys14 = PSY.System(nodes14, thermal_generators14, loads14, branches14, nothing,  100.0, forecasts14, nothing, nothing);
c_sys5 = PSY.ConcreteSystem(sys5)
c_sys14 = PSY.ConcreteSystem(sys14)
PTDF5 = PSY.PTDF(branches5, nodes5);
PTDF5 = PSY.PTDF(branches14, nodes14);


#System with Renewable Energy
sys5_re = PSY.System(nodes5, vcat(thermal_generators5, renewable_generators5), loads5, branches5, nothing,  100.0, forecasts5, nothing, nothing);
c_sys5_re = PSY.ConcreteSystem(sys5_re)

# RTS Data 
RTS_GMLC_DIR = joinpath(DATA_DIR, "RTS_GMLC")
cdm_dict = PSY.csv2ps_dict(RTS_GMLC_DIR, 100.0);
sys_rts = PSY.System(cdm_dict);
c_rts = PSY.ConcreteSystem(sys_rts);

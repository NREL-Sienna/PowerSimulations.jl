time_range = 1:24

base_dir = string(dirname(dirname(pathof(PowerSystems))));
include(joinpath(base_dir,"data/data_5bus_pu.jl"));
include(joinpath(base_dir,"data/data_14bus_pu.jl"))
DATA_DIR = joinpath(base_dir, "data")
RTS_GMLC_DIR = joinpath(DATA_DIR, "RTS_GMLC")
cdm_dict = PSY.csv2ps_dict(RTS_GMLC_DIR, 100.0);

sys5 = PSY.System(nodes14, thermal_generators5, loads5, branches5, nothing,  100.0, forecasts5, nothing, nothing);
sys14 = PSY.System(nodes14, thermal_generators14, loads14, branches14, nothing,  100.0, forecasts14, nothing, nothing);
sys_rts = PSY.System(cdm_dict);
c_sys5 = PSY.ConcreteSystem(sys5)
c_sys14 = PSY.ConcreteSystem(sys14)
c_rts = PSY.ConcreteSystem(sys_rts);
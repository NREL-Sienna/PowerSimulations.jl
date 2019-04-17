time_range = 1:24

base_dir = string(dirname(dirname(pathof(PowerSystems))));
include(joinpath(base_dir,"data/data_5bus_pu.jl"));
bus_numbers = [b.number for b in nodes5]

include(joinpath(base_dir,"data/data_14bus_pu.jl"))
sys14 = PSY.System(nodes14, generators14, loads14, branches14, nothing,  100.0, nothing, nothing, nothing);

DATA_DIR = joinpath(base_dir, "data")
RTS_GMLC_DIR = joinpath(DATA_DIR, "RTS_GMLC")
cdm_dict = PSY.csv2ps_dict(RTS_GMLC_DIR, 100.0)
sys_rts = PSY.System(cdm_dict);

sys5b = PSY.System(nodes5, vcat(generators5,renewables), loads5_DA, branches5, nothing,  100.0, nothing, nothing, nothing);
sys5b_uc = PSY.System(nodes5, generators5_uc, loads5_DA, branches5, nothing,  100.0, nothing, nothing, nothing);
sys5b_storage = PSY.System(nodes5, vcat(generators5_uc), loads5_DA, branches5, battery,  100.0, nothing, nothing, nothing);

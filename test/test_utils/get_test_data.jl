time_steps = 1:24

base_dir = string(dirname(dirname(pathof(PowerSystems))));
DATA_DIR = joinpath(base_dir, "data")
include(joinpath(base_dir,"data/data_5bus_pu.jl"));
include(joinpath(base_dir,"data/data_14bus_pu.jl"))
bus_numbers5 = [b.number for b in nodes5]
bus_numbers14 = [b.number for b in nodes14];

#Base Systems
sys5 = PSY._System(nodes5, thermal_generators5, loads5, branches5, nothing,  100.0, forecasts5, nothing, nothing);
sys14 = PSY._System(nodes14, thermal_generators14, loads14, branches14, nothing,  100.0, forecasts14, nothing, nothing);
c_sys5 = PSY.System(sys5)
c_sys14 = PSY.System(sys14)
PTDF5 = PSY.PTDF(branches5, nodes5);
PTDF14 = PSY.PTDF(branches14, nodes14);

#System with Renewable Energy
sys5_re = PSY._System(nodes5, vcat(thermal_generators5, renewable_generators5), loads5, branches5, nothing,  100.0, forecasts5, nothing, nothing);
c_sys5_re = PSY.System(sys5_re)

sys5_re_only = PSY._System(nodes5, renewable_generators5, loads5, branches5, nothing,  100.0, forecasts5, nothing, nothing);
c_sys5_re_only = PSY.System(sys5_re_only)

#System with Storage Device
sys5_bat = PSY._System(nodes5, thermal_generators5, loads5, branches5, battery5,  100.0, forecasts5, nothing, nothing);
c_sys5_bat = PSY.System(sys5_bat)

#Systems with HVDC data in the branches
sys5_dc = PSY._System(nodes5, thermal_generators5, loads5, branches5_dc, nothing,  100.0, forecasts5, nothing, nothing);
sys14_dc = PSY._System(nodes14, thermal_generators14, loads14, branches14_dc, nothing,  100.0, forecasts14, nothing, nothing);
c_sys5_dc = PSY.System(sys5_dc)
c_sys14_dc = PSY.System(sys14_dc)
b_ac_5 = collect(get_components(PSY.ACBranch, c_sys5_dc))
PTDF5_dc = PSY.PTDF(b_ac_5, nodes5);
b_ac_14 = collect(get_components(PSY.ACBranch, c_sys14_dc))
PTDF14_dc = PSY.PTDF(b_ac_14, nodes14);

# RTS Data
RTS_GMLC_DIR = joinpath(DATA_DIR, "RTS_GMLC")
#cdm_dict = PSY.csv2ps_dict(RTS_GMLC_DIR, 100.0);
#sys_rts = PSY._System(cdm_dict);
#c_rts = PSY.System(sys_rts);

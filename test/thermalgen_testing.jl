using PowerSystems
using PowerSimulations
using JuMP

const PS = PowerSimulations

base_dir = string(dirname(dirname(pathof(PowerSystems))))
println(joinpath(base_dir,"data/data_5bus_uc.jl"))
include(joinpath(base_dir,"data/data_5bus_uc.jl"))


sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 100.0)

#Generator Active and Reactive Power Variables
@test try
    Net = PS.StandardAC
    m = Model()
    netinjection = PS.instantiate_network(Net, sys5)
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5)
true finally end

#Cooper Plate and Dispatch
@test try
    Net = PS.CopperPlatePowerModel
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
true finally end

#PTDF Plate and Dispatch
@test try
    Net = PS.StandardPTDF
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalDispatch, Net, sys5);
true finally end

#PTDF and Ramping
@test try
    Net = PS.StandardPTDF
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalRampLimitDispatch, Net, sys5);
true finally end

#Cooper Plate and Ramping
@test try
    Net = PS.CopperPlatePowerModel
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.ThermalRampLimitDispatch, Net, sys5);
true finally end

#PTDF and Commitment
@test try
    Net = PS.StandardPTDF
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.StandardThermalCommitment, Net, sys5);
true finally end

#Copper Plate and Commitment
@test try
    Net = PS.CopperPlatePowerModel
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    PS.constructdevice!(m, netinjection, ThermalGen, PS.StandardThermalCommitment, Net, sys5);
true finally end


#Copper Plate and Commitment with args
@test try
    Net = PS.CopperPlatePowerModel
    m = Model();
    netinjection = PS.instantiate_network(Net, sys5);
    name_index = [gen.name for gen in sys5.generators.thermal];
    initialstatusdict = Dict(zip(name_index,ones(length(name_index))));
    initialondurationdict = Dict(zip(name_index,ones(length(name_index))*100));
    initialoffdurationdict = Dict(zip(name_index,zeros(length(name_index))));

    PS.constructdevice!(m, netinjection, ThermalGen, PS.StandardThermalCommitment, Net, sys5,
        initialstatus = initialstatusdict,
        initialonduration=initialondurationdict,
        initialoffduration = initialoffdurationdict);
true finally end

true

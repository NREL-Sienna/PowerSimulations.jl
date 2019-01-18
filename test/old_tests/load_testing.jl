using PowerSystems
using PowerSimulations
using JuMP

const PS = PowerSimulations

base_dir = string(dirname(dirname(pathof(PowerSystems))))
println(joinpath(base_dir,"data/data_5bus_uc.jl"))
include(joinpath(base_dir,"data/data_5bus_uc.jl"))


sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 100.0)

#Load Active and Reactive Power Variables
@test try
    Net = PSI.StandardAC
    m = Model()
    netinjection = PSI.instantiate_network(Net, sys5)
    PSI.constructdevice!(m, netinjection, ElectricLoad, PSI.InterruptibleLoad, Net, sys5)
true finally end

#Cooper Plate and Dispatch
@test try
    Net = PSI.CopperPlatePowerModel
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ElectricLoad, PSI.InterruptibleLoad, Net, sys5);
true finally end

#PTDF Plate and Dispatch
@test try
    Net = PSI.StandardPTDF
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ElectricLoad, PSI.InterruptibleLoad, Net, sys5);
true finally end
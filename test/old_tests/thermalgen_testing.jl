using PowerSystems
using PowerSimulations
using JuMP

const PS = PowerSimulations

base_dir = string(dirname(dirname(pathof(PowerSystems))))
println(joinpath(base_dir,"data/data_5bus_pu.jl"))
include(joinpath(base_dir,"data/data_5bus_pu.jl"))


sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 100.0)

ps_model = PSI.CanonicalModel(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                              Dict())

@test try
    PSI.activepowervariables(ps_model, generators5, 1:24)
    PSI.activepowervariables(ps_model, loads5_DA, 1:24)
    PSI.commitmentvariables(ps_model, generators5, 1:24)
    PSI.flowvariables(ps_model, PSI.DCAngleForm, branches5, 1:24)
true finally end

#=
#Generator Active and Reactive Power Variables
@test try
    Net = PSI.StandardAC
    m = Model()
    netinjection = PSI.instantiate_network(Net, sys5)
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5)
true finally end

#Cooper Plate and Dispatch
@test try
    Net = PSI.CopperPlatePowerModel
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
true finally end

#PTDF Plate and Dispatch
@test try
    Net = PSI.StandardPTDF
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalDispatch, Net, sys5);
true finally end

#PTDF and Ramping
@test try
    Net = PSI.StandardPTDF
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalRampLimitDispatch, Net, sys5);
true finally end

#Cooper Plate and Ramping
@test try
    Net = PSI.CopperPlatePowerModel
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.ThermalRampLimitDispatch, Net, sys5);
true finally end

#PTDF and Commitment
@test try
    Net = PSI.StandardPTDF
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.StandardThermalCommitment, Net, sys5);
true finally end

#Copper Plate and Commitment
@test try
    Net = PSI.CopperPlatePowerModel
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.StandardThermalCommitment, Net, sys5);
true finally end


#Copper Plate and Commitment with args
@test try
    Net = PSI.CopperPlatePowerModel
    m = Model();
    netinjection = PSI.instantiate_network(Net, sys5);
    name_index = [gen.name for gen in sys5.generators.thermal];
    initialstatusdict = Dict(zip(name_index,ones(length(name_index))));
    initialondurationdict = Dict(zip(name_index,ones(length(name_index))*100));
    initialoffdurationdict = Dict(zip(name_index,zeros(length(name_index))));

    PSI.constructdevice!(m, netinjection, ThermalGen, PSI.StandardThermalCommitment, Net, sys5,
        initialstatus = initialstatusdict,
        initialonduration=initialondurationdict,
        initialoffduration = initialoffdurationdict);
true finally end

=#

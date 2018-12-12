using PowerSystems
using PowerSimulations
using JuMP

const PS = PowerSimulations

base_dir = string(dirname(dirname(pathof(PowerSystems))))
println(joinpath(base_dir,"data/data_5bus_pu.jl"))
include(joinpath(base_dir,"data/data_5bus_pu.jl"))


sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 100.0)

ps_model = PS.canonical_model(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              Dict{String, PS.JumpAffineExpressionArray}("var_active" => PS.JumpAffineExpressionArray(undef, 14, 24),
                                                                         "var_reactive" => PS.JumpAffineExpressionArray(undef, 14, 24)),
                              Dict())

@test try PS.activepowervariables(ps_model, generators5, 1:24); true finally end
@test try PS.reactivepowervariables(ps_model, generators5, 1:24); true finally end
@test try PS.activepowervariables(ps_model, loads5_DA, 1:24); true finally end
@test try PS.reactivepowervariables(ps_model, loads5_DA, 1:24); true finally end
@test try PS.commitmentvariables(ps_model, generators5, 1:24); true finally end
@test try PS.flowvariables(ps_model, PS.DCAngleForm, branches5, 1:24); true finally end

#=
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

=#

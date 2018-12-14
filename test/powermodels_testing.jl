using InfrastructureModels
using PowerModels

const PM = PowerModels

# required for reducing logging during tests
using Memento

# Suppress warnings during testing.
setlevel!(getlogger(InfrastructureModels), "error")
setlevel!(getlogger(PowerModels), "error")


# required for "with_optimizer" function

# needed for model building (MOI does not currently suppot adding solvers after model creation)
using Ipopt
ipopt_optimizer = with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)

# is this the best way to find a file in a package?
base_dir = dirname(dirname(pathof(PowerSystems)))
case5_data = PowerSystems.parse_file(joinpath(base_dir,"data/matpower/case5.m"))
case5_data = InfrastructureModels.replicate(case5_data, 2)

case5_dc_data = PowerSystems.parse_file(joinpath(base_dir,"data/matpower/case5_dc.m"))
case5_dc_data = InfrastructureModels.replicate(case5_dc_data, 2)


# TODO: currently JuMP.num_variables is the best we can do to introspect the JuMP model.
#  Ideally this would also test the number of constraints generated

@test try
    pm = PowerSimulations.build_nip_model(case5_data, PM.DCPPowerModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 34
true finally end

@test try
    pm = PowerSimulations.build_nip_model(case5_data, PM.ACPPowerModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 96
true finally end

@test try
    pm = PowerSimulations.build_nip_model(case5_data, PM.SOCWRPowerModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 110
true finally end


# test PowerSimulations type extentions
DCAngleModel = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, PowerSimulations.DCAngleForm; kwargs...)

StandardACModel = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, PowerSimulations.StandardAC; kwargs...)


@test try
    pm = PowerSimulations.build_nip_model(case5_data, DCAngleModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 34
true finally end

# test PowerSimulations type extentions
@test try
    pm = PowerSimulations.build_nip_model(case5_data, StandardACModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 96
true finally end


# test models with HVDC line
@test try
    pm = PowerSimulations.build_nip_model(case5_dc_data, PM.DCPPowerModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 36
true finally end

@test try
    pm = PowerSimulations.build_nip_model(case5_dc_data, DCAngleModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 48
true finally end



@test try
    base_dir = dirname(dirname(pathof(PowerSystems)))
    include(joinpath(base_dir,"data/data_5bus_pu.jl"))
    PS_struct = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  100.0);
    netinjection = PS.instantiate_network(PS.DCAngleForm, PS_struct);
    PM_dict = PowerSimulations.pass_to_pm(PS_struct, netinjection)
    PM_object = PowerSimulations.build_nip_model(PM_dict, PM.DCPPowerModel, optimizer=ipopt_optimizer);
    JuMP.num_variables(PM_object.model) == 384
true finally end

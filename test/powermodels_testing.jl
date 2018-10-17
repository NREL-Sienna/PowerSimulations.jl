using PowerModels
const PM = PowerModels

# required for reducing logging during tests
using Memento
# Suppress warnings during testing.
using InfrastructureModels
setlevel!(getlogger(InfrastructureModels), "error")
setlevel!(getlogger(PowerModels), "error")


# required for "with_optimizer" function
using JuMP

# needed for model building (MOI does not currently suppot adding solvers after model creation)
using Ipopt
ipopt_optimizer = with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)

# is this the best way to find a file in a package?
case5_data = PM.parse_file("../test/data/case5.m")
case5_dc_data = PM.parse_file("../test/data/case5_dc.m")

#Lines of horrible code
base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus.jl"))
PS_struct = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  100.0);
PM_dict = PS.pass_to_pm(PS_struct)
PM_object = PS.build_nip_model(PM_dict, PM.DCPPowerModel, optimizer=ipopt_optimizer);


# TODO: currently JuMP.num_variables is the best we can do to introspect the JuMP model.
#  Ideally this would also test the number of constraints generated


@test try
    pm = PowerSimulations.build_nip_model(case5_data, PM.DCPPowerModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 17
true finally end

@test try
    pm = PowerSimulations.build_nip_model(case5_data, PM.ACPPowerModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 48
true finally end

@test try
    pm = PowerSimulations.build_nip_model(case5_data, PM.SOCWRPowerModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 55
true finally end


# test PowerSimulations type extentions
const DCAngleModel = PM.GenericPowerModel{PowerSimulations.DCAngleForm}

"default DC constructor"
DCAngleModel(data::Dict{String,Any}; kwargs...) =
    PM.GenericPowerModel(data, PowerSimulations.DCAngleForm; kwargs...)


const StandardACModel = PM.GenericPowerModel{PowerSimulations.StandardAC}

"default AC constructor"
StandardACModel(data::Dict{String,Any}; kwargs...) =
    PM.GenericPowerModel(data, PowerSimulations.StandardAC; kwargs...)


@test try
    pm = PowerSimulations.build_nip_model(case5_data, DCAngleModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 24
true finally end

# test PowerSimulations type extentions
@test try
    pm = PowerSimulations.build_nip_model(case5_data, StandardACModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 48
true finally end


# test models with HVDC line
@test try
    pm = PowerSimulations.build_nip_model(case5_dc_data, PM.DCPPowerModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 18
true finally end

@test try
    pm = PowerSimulations.build_nip_model(case5_dc_data, DCAngleModel, optimizer=ipopt_optimizer)
    JuMP.num_variables(pm.model) == 24
true finally end


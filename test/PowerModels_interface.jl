# Suppress warnings during testing.
setlevel!(getlogger(PowerModels), "error")

# is this the best way to find a file in a package?
base_dir = dirname(dirname(pathof(PowerSystems)))
case5_data = PM.parse_file(joinpath(base_dir,"data/matpower/case5.m"))
case5_data = PM.replicate(case5_data, 2)

case5_dc_data = PM.parse_file(joinpath(base_dir,"data/matpower/case5_dc.m"))
case5_dc_data = PM.replicate(case5_dc_data, 2)


# TODO: currently JuMP.num_variables is the best we can do to introspect the JuMP model.
#  Ideally this would also test the number of constraints generated

@testset "PowerModels Model Build" begin
    pm = PowerSimulations.build_nip_model(case5_data, PM.DCPPowerModel)
    @test JuMP.num_variables(pm.model) == 34
    pm = PowerSimulations.build_nip_model(case5_data, PM.ACPPowerModel)
    @test JuMP.num_variables(pm.model) == 96
    pm = PowerSimulations.build_nip_model(case5_data, PM.SOCWRPowerModel)
    @test JuMP.num_variables(pm.model) == 110
end


# test PowerSimulations type extentions
DCAngleModel = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, PM.DCPlosslessForm; kwargs...)

StandardACModel = (data::Dict{String,Any}; kwargs...) -> PM.GenericPowerModel(data, PM.StandardACPForm; kwargs...)

@testset "PM with type extensions" begin
    pm = PowerSimulations.build_nip_model(case5_data, DCAngleModel)
    JuMP.num_variables(pm.model) == 34
    pm = PowerSimulations.build_nip_model(case5_data, StandardACModel)
    JuMP.num_variables(pm.model) == 96
    pm = PowerSimulations.build_nip_model(case5_dc_data, PM.DCPPowerModel)
    JuMP.num_variables(pm.model) == 36
    pm = PowerSimulations.build_nip_model(case5_dc_data, DCAngleModel)
    JuMP.num_variables(pm.model) == 48
end



@testset "PM integration into PS" begin
    base_dir = dirname(dirname(pathof(PowerSystems)))
    include(joinpath(base_dir,"data/data_5bus_pu.jl"))
    PS_struct = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  100.0);
    PM_dict = PowerSimulations.pass_to_pm(PS_struct)
    PM_object = PowerSimulations.build_nip_model(PM_dict, DCAngleModel);
    @test JuMP.num_variables(PM_object.model) == 384
end

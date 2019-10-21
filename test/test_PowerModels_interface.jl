# Suppress warnings during testing.
# required for reducing logging during tests
using Memento
setlevel!(getlogger(PowerModels), "error")

# is this the best way to find a file in a package?
base_dir = string(dirname(dirname(pathof(PowerSystems))))
case5_data = PM.parse_file(joinpath(base_dir, "data/matpower/case5.m"))
case5_data = PM.replicate(case5_data, 2)

case5_dc_data = PM.parse_file(joinpath(base_dir, "data/matpower/case5_dc.m"))
case5_dc_data = PM.replicate(case5_dc_data, 2)

# TODO: currently JuMP.num_variables is the best we can do to introspect the JuMP model.
#  Ideally this would also test the number of constraints generated

@testset "PowerModels Model Build" begin
    pm = PowerSimulations.build_nip_model(case5_data, DCPPowerModel)
    @test JuMP.num_variables(pm.model) == 34
    pm = PowerSimulations.build_nip_model(case5_data, PM.ACPPowerModel)
    @test JuMP.num_variables(pm.model) == 96
    pm = PowerSimulations.build_nip_model(case5_data, PM.SOCWRPowerModel)
    @test JuMP.num_variables(pm.model) == 110
end

@testset "PM with type extensions" begin
    pm = PowerSimulations.build_nip_model(case5_data, DCPPowerModel)
    JuMP.num_variables(pm.model) == 34
    pm = PowerSimulations.build_nip_model(case5_data, ACPPowerModel)
    JuMP.num_variables(pm.model) == 96
    pm = PowerSimulations.build_nip_model(case5_dc_data, DCPPowerModel)
    JuMP.num_variables(pm.model) == 36
    pm = PowerSimulations.build_nip_model(case5_dc_data, DCPPowerModel)
    JuMP.num_variables(pm.model) == 48
end
#=
@testset "PM integration into PS" begin
    PM_dict5 = PowerSimulations.pass_to_pm(c_sys5, 24)
    PM_object5 = PowerSimulations.build_nip_model(PM_dict5, DCAngleModel);
    @test JuMP.num_variables(PM_object5.model) == 384

    PM_dict_rts = PowerSimulations.pass_to_pm(c_rts, 24)
    PM_object_rts = PowerSimulations.build_nip_model(PM_dict_rts, DCAngleModel);
    @test JuMP.num_variables(PM_object_rts.model) == 6432
end
=#

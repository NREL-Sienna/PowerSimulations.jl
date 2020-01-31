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
    pm = PowerSimulations.build_nip_model(case5_dc_data, DCPPowerModel)
    JuMP.num_variables(pm.model) == 34 # Repetitive?
    pm = PowerSimulations.build_nip_model(case5_dc_data, ACPPowerModel)
    JuMP.num_variables(pm.model) == 96
    pm = PowerSimulations.build_nip_model(case5_dc_data, DCPPowerModel)
    @test JuMP.num_variables(pm.model) == 36
    pm = PowerSimulations.build_nip_model(case5_dc_data, DCPPowerModel)
    @test JuMP.num_variables(pm.model) == 36 # 48 was originally here, verify??
end

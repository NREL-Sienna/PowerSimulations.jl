
function build_init(gens, data)
    init = Vector{InitialCondition}(undef, length(collect(gens))) 
    for (ix,g) in enumerate(gens)
        init[ix] = InitialCondition(g,
                    PSI.UpdateRef{PSY.Device}(Symbol("P_$(typeof(g))")),
                    data[ix],TimeStatusChange)
    end
    return init 
end

# Testing Ramping Constraint
branches = Dict{Symbol, PSI.DeviceModel}()
services = Dict{Symbol, PSI.ServiceModel}()
devices = Dict{Symbol, DeviceModel}(:Generators => PSI.DeviceModel(PSY.ThermalStandard, PSI.ThermalRampLimited),
                                    :Loads =>  PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))

@testset "Solving UC with CopperPlate for testing Ramping Constraints" begin
    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);
    UC = OperationModel(TestOptModel, model_ref,
                        ramp_test_sys; optimizer = GLPK_optimizer, 
                        parameters = true);
    psi_checksolve_test(UC, [MOI.OPTIMAL], 11191.00)
    moi_tests(UC, true, 10, 10, 10, 0, 5, false)
end

# Testing Duration Constraints
branches = Dict{Symbol,DeviceModel}()
services = Dict{Symbol,PSI.ServiceModel}()
devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalStandardUnitCommitment),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))

status = [0.0,1.0]
up_time = [0.0,2.0]
down_time = [3.0,0.0]

gens = get_components(PSY.ThermalGen,duration_test_sys)
alta = get_component(PSY.ThermalStandard,duration_test_sys,"Alta")
init_cond = PSI.DICKDA()
init_cond[PSI.ICKey(PSI.DeviceStatus,typeof(alta))] = build_init(gens, status)
init_cond[PSI.ICKey(PSI.TimeDurationON,typeof(alta))] = build_init(gens, up_time)
init_cond[PSI.ICKey(PSI.TimeDurationOFF,typeof(alta))] = build_init(gens, down_time)

@testset "Solving UC with CopperPlate for testing Duration Constraints" begin
    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);
    UC = OperationModel(TestOptModel, model_ref,
                        duration_test_sys; optimizer = GLPK_optimizer, 
                        parameters = true, initial_conditions = init_cond);
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8223.50)
    moi_tests(UC, true, 56, 0, 56, 14, 21, true)
end

## PWL linear Cost implementation test
@testset "Solving UC with CopperPlate testing Linear PWL" begin
    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);
    UC = OperationModel(TestOptModel, model_ref,
                        cost_test_sys; optimizer = GLPK_optimizer, 
                        parameters = true);
    psi_checksolve_test(UC, [MOI.OPTIMAL], 9336.736919354838)
    moi_tests(UC, true, 32, 0, 8, 4, 10, true)
end

## PWL SOS-2 Cost implementation test
@testset "Solving UC with CopperPlate testing SOS2 implementation" begin
    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);
    UC = OperationModel(TestOptModel, model_ref,
                        cost_test_sos_sys; optimizer = GLPK_optimizer, 
                        parameters = true);
    psi_checksolve_test(UC, [MOI.OPTIMAL], 9336.736919,10.0)
    moi_tests(UC, true, 32, 0, 8, 4, 14, true)
end
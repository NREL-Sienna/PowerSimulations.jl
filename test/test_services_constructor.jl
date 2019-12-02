@testset "Testing Reserves from Thermal Dispatch" begin
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(ThermalStandard, ThermalDispatch),
                                        :Loads =>  DeviceModel(PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(:Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    model_template = OperationsProblemTemplate(CopperPlatePowerModel , devices, branches, services_template)
    for p in [true, false]
        op_problem = OperationsProblem(TestOpProblem, model_template, c_sys5_uc; use_parameters=p)
        moi_tests(op_problem, p, 264, 0, 120, 168, 24, false)
    end
end

@testset "Testing Reserves from Thermal Standard UC" begin
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
                                        :Loads =>  DeviceModel(PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(:Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    model_template = OperationsProblemTemplate(CopperPlatePowerModel , devices, branches, services_template)
    for p in [true, false]
        op_problem = OperationsProblem(TestOpProblem, model_template, c_sys5_uc; use_parameters=p)
        moi_tests(op_problem, p, 624, 0, 240, 168, 144, true)
    end
end

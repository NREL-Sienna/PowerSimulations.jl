@testset "Testing Reserves from Thermal Dispatch" begin
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(ThermalStandard, ThermalDispatch),
                                        :Loads =>  DeviceModel(PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(:Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
                                                        :DownReserve => ServiceModel(VariableReserve{ReserveDown}, RangeReserve))
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
    services_template = Dict{Symbol, PSI.ServiceModel}(:UpReserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
                                                        :DownReserve => ServiceModel(VariableReserve{ReserveDown}, RangeReserve))
    model_template = OperationsProblemTemplate(CopperPlatePowerModel , devices, branches, services_template)
    for p in [true, false]
        op_problem = OperationsProblem(TestOpProblem, model_template, c_sys5_uc; use_parameters=p)
        moi_tests(op_problem, p, 624, 0, 240, 168, 144, true)
    end
end

@testset "Testing Reserves from Renewable Dispatch" begin
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(RenewableDispatch, RenewableFullDispatch),
                                        :Loads =>  DeviceModel(PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(:Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
                                                        :DownReserve => ServiceModel(VariableReserve{ReserveDown}, RangeReserve))
    model_template = OperationsProblemTemplate(CopperPlatePowerModel , devices, branches, services_template)
    for p in [true, false]
        op_problem = OperationsProblem(TestOpProblem, model_template, c_sys5_re; use_parameters=p)
        moi_tests(op_problem, p, 168, 0, 72, 120, 24, false)
    end
end

@testset "Testing Reserves from Storage" begin
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(RenewableDispatch, RenewableFullDispatch),
                                        :Loads =>  DeviceModel(PowerLoad, PSI.StaticPowerLoad))
    branches = Dict{Symbol, DeviceModel}()
    services_template = Dict{Symbol, PSI.ServiceModel}(:Reserve => ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    model_template = OperationsProblemTemplate(CopperPlatePowerModel , devices, branches, services_template)
    for p in [true, false]
        op_problem = OperationsProblem(TestOpProblem, model_template, c_sys5_re; use_parameters=p)
        moi_tests(op_problem, p, 144, 0, 72, 24, 24, false)
    end
end

#TODO: add test for hydro Reserves

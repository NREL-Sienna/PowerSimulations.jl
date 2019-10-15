devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, ThermalDispatch),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, StaticPowerLoad))
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, StaticLineUnbounded))
services = Dict{Symbol, ServiceModel}()

@testset "Operation set ref models" begin
    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);
    op_model = OperationModel(TestOptModel, model_ref, c_sys5)
    set_transmission_ref!(op_model, DCPLLPowerModel)
    @test op_model.model_ref.transmission == DCPLLPowerModel

    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);
    op_model = OperationModel(TestOptModel, model_ref, c_sys5)
    new_devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, ThermalBasicUnitCommitment),
                                            :Loads =>  DeviceModel(PSY.PowerLoad, StaticPowerLoad))
    set_devices_ref!(op_model, new_devices)
    @test op_model.model_ref.devices[:Generators].formulation == ThermalBasicUnitCommitment
    jump_model = op_model.canonical.JuMPmodel
    @test ((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(jump_model)) == true

    model_ref = ModelReference(DCPPowerModel, devices, branches, services);
    op_model = OperationModel(TestOptModel, model_ref, c_sys5)
    new_branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, StaticLine))
    set_branches_ref!(op_model, new_branches)
    @test op_model.model_ref.branches[:L].formulation == StaticLine
end


@testset "Operation set models" begin
    model_ref = ModelReference(CopperPlatePowerModel, devices, branches, services);
    op_model = OperationModel(TestOptModel, model_ref, c_sys5)
    set_device_model!(op_model, :Generators, DeviceModel(PSY.ThermalStandard, ThermalBasicUnitCommitment))
    @test op_model.model_ref.devices[:Generators].formulation == ThermalBasicUnitCommitment
    jump_model = op_model.canonical.JuMPmodel
    @test ((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(jump_model)) == true

    model_ref = ModelReference(DCPPowerModel, devices, branches, services);
    op_model = OperationModel(TestOptModel, model_ref, c_sys5)
    set_branch_model!(op_model, :L, DeviceModel(PSY.Line, StaticLine))
    @test op_model.model_ref.branches[:L].formulation == StaticLine
end

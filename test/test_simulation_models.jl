branches = Dict{Symbol, DeviceModel}()
services = Dict{Symbol, ServiceModel}()
devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
                                    :Ren => DeviceModel(RenewableDispatch, RenewableFixed),
                                    :Loads =>  DeviceModel(PowerLoad, StaticPowerLoad),
                                    :ILoads =>  DeviceModel(InterruptibleLoad, StaticPowerLoad),
                                    )
template_uc= OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services);

## ED Model Ref
branches = Dict{Symbol, DeviceModel}()
services = Dict{Symbol, ServiceModel}()
devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(ThermalStandard, ThermalDispatchNoMin, SemiContinuousFF(:P, :ON)),
                                    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
                                    :Loads =>  DeviceModel(PowerLoad, StaticPowerLoad),
                                    :ILoads =>  DeviceModel(InterruptibleLoad, DispatchablePowerLoad),
                                    )
template_ed= OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services);

#=
## UC Model Ref
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(Line, StaticLine),
                                     :T => DeviceModel(Transformer2W, StaticTransformer),
                                     :TT => DeviceModel(TapTransformer, StaticTransformer),
                                     :dc_line => DeviceModel(HVDCLine, HVDCDispatch))

services = Dict{Symbol, ServiceModel}()

devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
                                    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
                                    :Loads =>  DeviceModel(PowerLoad, StaticPowerLoad),
                                    :ILoads =>  DeviceModel(InterruptibleLoad, StaticPowerLoad))


template_uc= OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services);

## ED Model Ref
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(Line, StaticLine),
                                     :T => DeviceModel(Transformer2W, StaticTransformer),
                                     :TT => DeviceModel(TapTransformer, StaticTransformer),
                                     :dc_line => DeviceModel(HVDCLine, HVDCDispatch))

services = Dict{Symbol, ServiceModel}()

devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(ThermalStandard, ThermalDispatch, SemiContinuousFF(:P, :ON)),
                                    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
                                    :Loads =>  DeviceModel(PowerLoad, StaticPowerLoad),
                                    :ILoads =>  DeviceModel(InterruptibleLoad, InterruptiblePowerLoad,))

template_ed= OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services);
=#

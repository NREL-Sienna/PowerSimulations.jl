## UC Model Ref
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.StaticLine),
                                     :T => DeviceModel(PSY.Transformer2W, PSI.StaticTransformer),
                                     :TT => DeviceModel(PSY.TapTransformer, PSI.StaticTransformer),
                                     :dc_line => DeviceModel(PSY.HVDCLine, PSI.HVDCDispatch))

services = Dict{Symbol, PSI.ServiceModel}()

devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalUnitCommitment),
                                    :Ren => DeviceModel(PSY.RenewableDispatch, PSI.RenewableFullDispatch),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad),
                                    :ILoads =>  DeviceModel(PSY.InterruptibleLoad, PSI.StaticPowerLoad))


model_ref_uc= ModelReference(CopperPlatePowerModel, devices, branches, services);

## ED Model Ref
branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(PSY.Line, PSI.StaticLine),
                                     :T => DeviceModel(PSY.Transformer2W, PSI.StaticTransformer),
                                     :TT => DeviceModel(PSY.TapTransformer, PSI.StaticTransformer),
                                     :dc_line => DeviceModel(PSY.HVDCLine, PSI.HVDCDispatch))

services = Dict{Symbol, PSI.ServiceModel}()

devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch, SemiContinuousFF(:P, :ON)),
                                    :Ren => DeviceModel(PSY.RenewableDispatch, PSI.RenewableFullDispatch, RangeFF(:P)),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad),
                                    :ILoads =>  DeviceModel(PSY.InterruptibleLoad, PSI.InterruptiblePowerLoad,))

model_ref_ed= ModelReference(CopperPlatePowerModel, devices, branches, services);


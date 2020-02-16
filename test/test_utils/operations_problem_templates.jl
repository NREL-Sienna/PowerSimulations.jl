## UC Model Ref
branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
    :Ren => DeviceModel(RenewableDispatch, RenewableFixed),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :ILoads => DeviceModel(InterruptibleLoad, StaticPowerLoad),
)
template_basic_uc =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
    :Ren => DeviceModel(RenewableDispatch, RenewableFixed),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :ILoads => DeviceModel(InterruptibleLoad, StaticPowerLoad),
)
template_standard_uc =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

## ED Model Ref
branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalDispatchNoMin),
    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :ILoads => DeviceModel(InterruptibleLoad, DispatchablePowerLoad),
)
template_ed = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

## UC with services Model Ref
branches = Dict()
services = Dict(
    :ReserveUp => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
    :ReserveDown => ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
)
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
    :Ren => DeviceModel(RenewableDispatch, RenewableFixed),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :ILoads => DeviceModel(InterruptibleLoad, StaticPowerLoad),
)
template_basic_uc_svc =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

# UC with Hydro Model Ref
branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :HydroEnergyReservoir => DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver),
)
template_hydro_basic_uc =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :HydroEnergyReservoir => DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver),
)
template_hydro_standard_uc =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

## ED with Hydro Model Ref
branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalDispatchNoMin),
    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :ILoads => DeviceModel(InterruptibleLoad, DispatchablePowerLoad),
    :HydroEnergyReservoir =>
            DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirFlow),
)
template_hydro_ed =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
#=
## UC Model Ref
branches = Dict(:L => DeviceModel(Line, StaticLine),
                                     :T => DeviceModel(Transformer2W, StaticTransformer),
                                     :TT => DeviceModel(TapTransformer, StaticTransformer),
                                     :dc_line => DeviceModel(HVDCLine, HVDCDispatch))

services = Dict()

devices = Dict(:Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
                                    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
                                    :Loads =>  DeviceModel(PowerLoad, StaticPowerLoad),
                                    :ILoads =>  DeviceModel(InterruptibleLoad, StaticPowerLoad))

template_basic_uc= OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

## ED Model Ref
branches = Dict(:L => DeviceModel(Line, StaticLine),
                                     :T => DeviceModel(Transformer2W, StaticTransformer),
                                     :TT => DeviceModel(TapTransformer, StaticTransformer),
                                     :dc_line => DeviceModel(HVDCLine, HVDCDispatch))

services = Dict()

devices = Dict(:Generators => DeviceModel(ThermalStandard, ThermalDispatch, SemiContinuousFF(PSI.ACTIVE_POWER, PSI.ON),
                                    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
                                    :Loads =>  DeviceModel(PowerLoad, StaticPowerLoad),
                                    :ILoads =>  DeviceModel(InterruptibleLoad, InterruptiblePowerLoad,))

template_ed= OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
=#

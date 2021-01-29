function get_thermal_standard_uc_template()
    template = OperationsProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    return template
end

function get_thermal_dispatch_template_network(network = CopperPlatePowerModel)
    template = OperationsProblemTemplate(network)
    set_device_model!(template, ThermalStandard, ThermalDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, MonitoredLine, StaticLineBounds)
    set_device_model!(template, Line, StaticLineUnbounded)
    return template
end

#=
## UC Model Ref
branches = Dict{String, DeviceModel}()
services = Dict{String, ServiceModel}()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
    :Ren => DeviceModel(RenewableDispatch, FixedOutput),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :ILoads => DeviceModel(InterruptibleLoad, StaticPowerLoad),
)
template_basic_uc =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
    :Ren => DeviceModel(RenewableDispatch, FixedOutput),
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
template_ed_ptdf = OperationsProblemTemplate(StandardPTDFModel, devices, branches, services)

## UC with services Model Ref
branches = Dict()
services = Dict(
    :ReserveUp => ServiceModel(VariableReserve{ReserveUp}, RangeReserve),
    :ReserveDown => ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
)
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
    :Ren => DeviceModel(RenewableDispatch, FixedOutput),
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
        DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirBudget),
)
template_hydro_ed =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

# UC with Hydro Model Ref
branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :HydroEnergyReservoir => DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver),
)
template_pwl_standard_uc =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

## ED with Hydro Model Ref
branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalRampLimited),
    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :ILoads => DeviceModel(InterruptibleLoad, DispatchablePowerLoad),
    :HydroEnergyReservoir =>
        DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirBudget),
)
template_pwl_ed =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

devices = Dict(
    :Generators => DeviceModel(ThermalMultiStart, ThermalMultiStartUnitCommitment),
    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :RenFx => DeviceModel(RenewableFix, FixedOutput),
)
template_multi_start_uc = template_unit_commitment(devices = devices)

branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :ILoads => DeviceModel(InterruptibleLoad, DispatchablePowerLoad),
    :HydroEnergyReservoir =>
        DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirStorage),
)
template_hydro_st_uc =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

## ED with HydroEnergyReservoir Model Ref
branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalDispatch),
    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :ILoads => DeviceModel(InterruptibleLoad, DispatchablePowerLoad),
    :HydroEnergyReservoir =>
        DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirStorage),
)
template_hydro_st_ed =
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
=#

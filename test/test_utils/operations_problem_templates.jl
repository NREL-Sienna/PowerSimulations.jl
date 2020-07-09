## UC Model Ref
branches = Dict{Symbol, DeviceModel}()
services = Dict{Symbol, ServiceModel}()
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
        DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirFlow),
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
        DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirFlow),
)
template_pwl_ed =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

function PSI._jump_value(int::Int64)
    @warn("This is for testing purposes only.")
    return int
end

function _test_plain_print_methods(list::Array)
    for object in list
        normal = repr(object)
        io = IOBuffer()
        show(io, "text/plain", object)
        grabbed = String(take!(io))
        @test !isnothing(grabbed)
    end
end

function _test_html_print_methods(list::Array)
    for object in list
        normal = repr(object)
        io = IOBuffer()
        show(io, "text/html", object)
        grabbed = String(take!(io))
        @test !isnothing(grabbed)
    end
end

struct FakeStagesStruct
    stages::Dict{Int64, Int64}
end
function Base.show(io::IO, struct_stages::FakeStagesStruct)
    PSI._print_inter_stages(io, struct_stages.stages)
    println(io, "\n\n")
    PSI._print_intra_stages(io, struct_stages.stages)
end

branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :HydroEnergyReservoir =>
        DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirStorage),
)
template_hydro_st_standard_uc =
    OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)

## ED with HydroEnergyReservoir Model Ref
branches = Dict()
services = Dict()
devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalDispatchNoMin),
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

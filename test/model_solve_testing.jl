using PowerSystems
using JuMP
using PowerSimulations  
using GLPK
const PS = PowerSimulations

# ED Testing
base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 100.0,runchecks=false);
simple_reserve = PowerSystems.StaticReserve("test_reserve",sys5.generators.thermal,60.0,[gen.tech for gen in sys5.generators.thermal])

# ED with thermal gen, static load, copper plate
@test try
    @info "ED with thermal gen, static load, copper plate"
    ED = PS.PowerOperationModel(PS.EconomicDispatch, 
                            [(device = ThermalGen, formulation =PS.ThermalDispatch)], 
                            nothing,
                            nothing, 
                            [(device=Line, formulation=PS.PiLine)],
                            PS.CopperPlatePowerModel,
                            nothing, 
                            sys5,
                            Model(), 
                            false,
                            nothing)
    PS.buildmodel!(sys5,ED)
    JuMP.optimize!(ED.model,with_optimizer(GLPK.Optimizer))
    (ED.model.moi_backend.model.optimizer.termination_status == JuMP.MOI.Success)  ? true : @error("solver returned with nonzero status") 
true finally end

# ED with thermal and curtailable renewable gen, static load, copper plate
@test try
    @info "ED with thermal and curtailable renewable gen, static load, copper plate"
    ED = PS.PowerOperationModel(PS.EconomicDispatch, 
                            [(device = ThermalGen, formulation =PS.ThermalDispatch),
                             (device = RenewableGen, formulation = PS.RenewableCurtail)], 
                            nothing,
                            nothing, 
                            [(device=Line, formulation=PS.PiLine)],
                            PS.CopperPlatePowerModel,
                            nothing, 
                            sys5,
                            Model(), 
                            false,
                            nothing)
    PS.buildmodel!(sys5,ED)
    JuMP.optimize!(ED.model,with_optimizer(GLPK.Optimizer))
    (ED.model.moi_backend.model.optimizer.termination_status == JuMP.MOI.Success) ? true : @error("solver returned with nonzero status") 
true finally end

# ED with thermal and fixed renewable gen, interruptable load, copper plate
@test try
    @info "ED with thermal and fixed renewable gen, interruptable load, copper plate"
    ED = PS.PowerOperationModel(PS.EconomicDispatch, 
                            [(device = ThermalGen, formulation = PS.ThermalDispatch),
                            (device = RenewableGen, formulation = PS.RenewableCurtail)], 
                            [(device = ElectricLoad, formulation = PS.InterruptibleLoad)],
                            nothing, 
                            [(device=Line, formulation=PS.PiLine)],
                            PS.CopperPlatePowerModel,
                            nothing, 
                            sys5,
                            Model(), 
                            false,
                            nothing)
    PS.buildmodel!(sys5,ED)
    JuMP.optimize!(ED.model,with_optimizer(GLPK.Optimizer))
    (ED.model.moi_backend.model.optimizer.termination_status == JuMP.MOI.Success)  ? true : @error("solver returned with nonzero status") 
true finally end

# ED with thermal gen, copper plate, and reserve
@test try
    @info "ED with thermal gen, copper plate, and reserve"
    ED = PS.PowerOperationModel(PS.EconomicDispatch, 
                            [(device = ThermalGen, formulation =PS.ThermalDispatch)], 
                            nothing,
                            nothing, 
                            [(device=Line, formulation=PS.PiLine)],
                            PS.CopperPlatePowerModel,
                            [(service = simple_reserve, formulation = PS.RampLimitedReserve)], 
                            sys5,
                            Model(), 
                            false,
                            nothing)
    PS.buildmodel!(sys5,ED)
    JuMP.optimize!(ED.model,with_optimizer(GLPK.Optimizer))
    (ED.model.moi_backend.model.optimizer.termination_status == JuMP.MOI.Success)  ? true : @error("solver returned with nonzero status") 
true finally end


# ED with thermal gen, PTDF
@test try
    @info "ED with thermal gen, copper plate, and reserve"
    ED = PS.PowerOperationModel(PS.EconomicDispatch, 
                            [(device = ThermalGen, formulation =PS.ThermalDispatch),
                            (device = RenewableGen, formulation = PS.RenewableCurtail)], 
                            nothing,
                            nothing, 
                            [(device=Branch, formulation=PS.PiLine)],
                            PS.StandardPTDF,
                            nothing, 
                            sys5,
                            Model(), 
                            false,
                            nothing)
    PS.buildmodel!(sys5,ED)
    JuMP.optimize!(ED.model,with_optimizer(GLPK.Optimizer))
    (ED.model.moi_backend.model.optimizer.termination_status == JuMP.MOI.Success)  ? true : @error("solver returned with nonzero status") 
true finally end

# UC Testing
base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus_uc.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 100.0, runchecks=false);
simple_reserve = PowerSystems.StaticReserve("test_reserve",sys5.generators.thermal,60.0,[sys5.generators.thermal[1].tech])

# UC with thermal gen, static load, copper plate
@test try
    @info "UC with thermal gen, static load, copper plate"
    UC = PS.PowerOperationModel(PS.UnitCommitment, 
                            [(device = ThermalGen, formulation =PS.StandardThermalCommitment)], 
                            nothing,
                            nothing, 
                            [(device=Branch, formulation=PS.PiLine)],
                            PS.CopperPlatePowerModel,
                            nothing, 
                            sys5,
                            Model(), 
                            false,
                            nothing)
    PS.buildmodel!(sys5,UC)
    JuMP.optimize!(UC.model,with_optimizer(GLPK.Optimizer))
    (UC.model.moi_backend.model.optimizer.termination_status == JuMP.MOI.Success)  ? true : @error("solver returned with nonzero status") 
true finally end

# UC with thermal and curtailable renewable gen, static load, copper plate
@test try
    @info "UC with thermal and curtailable renewable gen, static load, copper plate"
    UC = PS.PowerOperationModel(PS.EconomicDispatch, 
                            [(device = ThermalGen, formulation =PS.StandardThermalCommitment),
                             (device = RenewableGen, formulation = PS.RenewableCurtail)], 
                            nothing,
                            nothing, 
                            [(device=Line, formulation=PS.PiLine)],
                            PS.CopperPlatePowerModel,
                            nothing, 
                            sys5,
                            Model(), 
                            false,
                            nothing)
    PS.buildmodel!(sys5,UC)
    JuMP.optimize!(UC.model,with_optimizer(GLPK.Optimizer))
true finally end

# UC with thermal and fixUC renewable gen, interruptable load, copper plate
@test try
    @info "UC with thermal and fixUC renewable gen, interruptable load, copper plate"
    UC = PS.PowerOperationModel(PS.UnitCommitment, 
                            [(device = ThermalGen, formulation = PS.StandardThermalCommitment),
                             (device = RenewableGen, formulation = PS.RenewableCurtail)], 
                            [(device = ElectricLoad, formulation = PS.InterruptibleLoad)],
                            nothing, 
                            [(device=Line, formulation=PS.PiLine)],
                            PS.CopperPlatePowerModel,
                            nothing, 
                            sys5,
                            Model(), 
                            false,
                            nothing)
    PS.buildmodel!(sys5,UC)
    JuMP.optimize!(UC.model,with_optimizer(GLPK.Optimizer))
    (UC.model.moi_backend.model.optimizer.termination_status == JuMP.MOI.Success)  ? true : @error("solver returned with nonzero status") 
true finally end

# UC with thermal gen, copper plate, and reserve
@test try
    @info "UC with thermal gen, copper plate, and reserve"
    UC = PS.PowerOperationModel(PS.EconomicDispatch, 
                            [(device = ThermalGen, formulation =PS.StandardThermalCommitment),
                            (device = RenewableGen, formulation = PS.RenewableCurtail)], 
                            nothing,
                            nothing, 
                            [(device=Line, formulation=PS.PiLine)],
                            PS.CopperPlatePowerModel,
                            [(service = simple_reserve, formulation = PS.RampLimitedReserve)], 
                            sys5,
                            Model(), 
                            false,
                            nothing)
    PS.buildmodel!(sys5,UC)
    JuMP.optimize!(UC.model,with_optimizer(GLPK.Optimizer))
    (UC.model.moi_backend.model.optimizer.termination_status == JuMP.MOI.Success)  ? true : @error("solver returned with nonzero status") 
true finally end


# UC with thermal gen, copper plate, and PTDF
@test try
    @info "UC with thermal gen, copper plate, and reserve"
    UC = PS.PowerOperationModel(PS.EconomicDispatch, 
                            [(device = ThermalGen, formulation =PS.StandardThermalCommitment),
                            (device = RenewableGen, formulation = PS.RenewableCurtail)], 
                            nothing,
                            nothing, 
                            [(device=Branch, formulation=PS.PiLine)],
                            PS.StandardPTDF,
                            nothing,
                            sys5,
                            Model(), 
                            false,
                            nothing)
    PS.buildmodel!(sys5,UC)
    JuMP.optimize!(UC.model,with_optimizer(GLPK.Optimizer))
    (UC.model.moi_backend.model.optimizer.termination_status == JuMP.MOI.Success)  ? true : @error("solver returned with nonzero status") 
true finally end
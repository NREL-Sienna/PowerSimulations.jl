using PowerSystems
using JuMP
using PowerSimulations
const PS = PowerSimulations

# ED Testing
base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 100.0);
#simple_reserve = PSY.StaticReserve("test_reserve",sys5.generators.thermal,60.0,[gen.tech for gen in sys5.generators.thermal])

# ED with thermal gen, static load, copper plate
@test try
    ED = PSI.PowerOperationModel(PSI.EconomicDispatch,
                            [(device = ThermalGen, formulation =PSI.ThermalDispatch)],
                            nothing,
                            nothing,
                            [(device=Line, formulation=PSI.PiLine)],
                            PSI.CopperPlatePowerModel,
                            nothing,
                            sys5,
                            Model(),
                            false,
                            nothing)
    PSI.buildmodel!(ED,sys5)
    #JuMP.optimize!(ED.model,with_optimizer(GLPK.Optimizer))
true finally end

# ED with thermal and curtailable renewable gen, static load, copper plate
@test try
    ED = PSI.PowerOperationModel(PSI.EconomicDispatch,
                            [(device = ThermalGen, formulation =PSI.ThermalDispatch),
                             (device = RenewableGen, formulation = PSI.RenewableCurtail)],
                            nothing,
                            nothing,
                            [(device=Line, formulation=PSI.PiLine)],
                            PSI.CopperPlatePowerModel,
                            nothing,
                            sys5,
                            Model(),
                            false,
                            nothing)
    PSI.buildmodel!(ED,sys5)
    #JuMP.optimize!(ED.model,with_optimizer(GLPK.Optimizer))
true finally end

# ED with thermal and fixed renewable gen, interruptable load, copper plate
@test try
    ED = PSI.PowerOperationModel(PSI.EconomicDispatch,
                            [(device = ThermalGen, formulation = PSI.ThermalDispatch),
                             (device = RenewableGen, formulation = PSI.RenewableCurtail)],
                            [(device = ElectricLoad, formulation = PSI.InterruptibleLoad)],
                            nothing,
                            [(device=Line, formulation=PSI.PiLine)],
                            PSI.CopperPlatePowerModel,
                            nothing,
                            sys5,
                            Model(),
                            false,
                            nothing)
    PSI.buildmodel!(ED,sys5)
    #JuMP.optimize!(ED.model,with_optimizer(GLPK.Optimizer))
true finally end

# ED with thermal gen, copper plate, and reserve
@test try
    ED = PSI.PowerOperationModel(PSI.EconomicDispatch,
                            [(device = ThermalGen, formulation =PSI.ThermalDispatch)],
                            nothing,
                            nothing,
                            [(device=Line, formulation=PSI.PiLine)],
                            PSI.CopperPlatePowerModel,
                            [(service = reserve5, formulation = PSI.RampLimitedReserve)],
                            sys5,
                            Model(),
                            false,
                            nothing)
    PSI.buildmodel!(ED,sys5)
    #JuMP.optimize!(ED.model,with_optimizer(GLPK.Optimizer))
    #ED.model.moi_backend.model.optimizer.termination_status
true finally end

# UC Testing
base_dir = dirname(dirname(pathof(PowerSystems)))
include(joinpath(base_dir,"data/data_5bus_uc.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 100.0);

# UC with thermal gen, static load, copper plate
@test try
    UC = PSI.PowerOperationModel(PSI.EconomicDispatch,
                            [(device = ThermalGen, formulation =PSI.ThermalUnitCommitment )],
                            nothing,
                            nothing,
                            [(device=Line, formulation=PSI.PiLine)],
                            PSI.CopperPlatePowerModel,
                            nothing,
                            sys5,
                            Model(),
                            false,
                            nothing)
    PSI.buildmodel!(UC,sys5)
    #JuMP.optimize!(UC.model,with_optimizer(GLPK.Optimizer))
true finally end

# UC with thermal and curtailable renewable gen, static load, copper plate
@test try
    UC = PSI.PowerOperationModel(PSI.EconomicDispatch,
                            [(device = ThermalGen, formulation =PSI.ThermalUnitCommitment ),
                             (device = RenewableGen, formulation = PSI.RenewableCurtail)],
                            nothing,
                            nothing,
                            [(device=Line, formulation=PSI.PiLine)],
                            PSI.CopperPlatePowerModel,
                            nothing,
                            sys5,
                            Model(),
                            false,
                            nothing)
    PSI.buildmodel!(UC,sys5)
    #JuMP.optimize!(UC.model,with_optimizer(GLPK.Optimizer))
true finally end

# UC with thermal and fixUC renewable gen, interruptable load, copper plate
@test try
    UC = PSI.PowerOperationModel(PSI.EconomicDispatch,
                            [(device = ThermalGen, formulation = PSI.ThermalUnitCommitment ),
                             (device = RenewableGen, formulation = PSI.RenewableCurtail)],
                            [(device = ElectricLoad, formulation = PSI.InterruptibleLoad)],
                            nothing,
                            [(device=Line, formulation=PSI.PiLine)],
                            PSI.CopperPlatePowerModel,
                            nothing,
                            sys5,
                            Model(),
                            false,
                            nothing)
    PSI.buildmodel!(UC,sys5)
    #JuMP.optimize!(UC.model,with_optimizer(GLPK.Optimizer))
true finally end

# UC with thermal gen, copper plate, and reserve
@test try
    UC = PSI.PowerOperationModel(PSI.EconomicDispatch,
                            [(device = ThermalGen, formulation =PSI.ThermalUnitCommitment )],
                            nothing,
                            nothing,
                            [(device=Line, formulation=PSI.PiLine)],
                            PSI.CopperPlatePowerModel,
                            [(service = reserve5, formulation = PSI.RampLimitedReserve)],
                            sys5,
                            Model(),
                            false,
                            nothing)
    PSI.buildmodel!(UC,sys5)
    #JuMP.optimize!(UC.model,with_optimizer(GLPK.Optimizer))
    #UC.model.moi_backend.model.optimizer.termination_status
true finally end

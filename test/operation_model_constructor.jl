#Inputs to the OperationModel
devices = Dict{String, PSI.DeviceModel}("Generators" => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalUnitCommitment),
                "Loads" => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))
branches = Dict{String, PSI.DeviceModel}("Lines" => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))
services = Dict{String, DataType}("Reserves" => PSI.AbstractServiceFormulation)

op_model = PSI.PowerOperationModel(PSI.UnitCommitment, PM.StandardACPForm, devices, branches, services, sys5b)
@test "var_active" in keys(op_model.canonical_model.expressions) && "var_reactive" in keys(op_model.canonical_model.expressions)

op_model = PSI.PowerOperationModel(PSI.UnitCommitment, PM.DCPlosslessForm, devices, branches, services, sys5b)
@test "var_active" in keys(op_model.canonical_model.expressions)

op_model = PSI.PowerOperationModel(PSI.UnitCommitment, PSI.StandardPTDFModel, devices, branches, services, sys5b)
@test "var_active" in keys(op_model.canonical_model.expressions)

op_model = PSI.PowerOperationModel(PSI.UnitCommitment, PSI.CopperPlatePowerModel, devices, branches, services, sys5b)
@test "var_active" in keys(op_model.canonical_model.expressions)

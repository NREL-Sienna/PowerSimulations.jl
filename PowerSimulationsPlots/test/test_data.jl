using PowerSimulationsPlots
using DataFrames
using Dates
using PowerSimulations
const PSI = PowerSimulations
variables = Dict()
variables[:P_ThermalStandard] = DataFrames.DataFrame(
    :one => [1, 2, 3, 2, 1],
    :two => [3, 2, 1, 2, 3],
    :three => [1, 2, 3, 2, 1],
)
variables[:P_RenewableDispatch] = DataFrames.DataFrame(
    :one => [3, 2, 3, 2, 3],
    :two => [1, 2, 1, 2, 1],
    :three => [3, 2, 3, 2, 3],
)
optimizer_log = Dict()
objective_value = Dict()
right_now = round(Dates.now(), Dates.Hour)
time_stamp =
    DataFrames.DataFrame(:Range => right_now:Dates.Hour(1):(right_now + Dates.Hour(4)))

res = PSI.OperationsProblemResults(variables, optimizer_log, objective_value, time_stamp)

generators = Dict("Coal" => [:one; :two], "Wind" => [:three])

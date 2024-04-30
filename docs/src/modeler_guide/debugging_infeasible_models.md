# Debugging infeasible models

Getting infeasible solutions to models is a common occurrence in operations simulations, there are multiple reasons why this can happen.
`PowerSimulations.jl` has several tools to help debug this situation.

## Adding slacks to the model

One of the most common infeasibility issues observed is due to not enough generation to supply demand, or conversely, excessive fixed (non-curtailable) generation in a low demand scenario. 

The recommended solution for any of these cases is adding slack variables to the network model, for example:

```julia
template_uc = ProblemTemplate(
        NetworkModel(
            CopperPlatePowerModel,
            use_slacks=true,
        ),
    )
```
will add slack variables to the `ActivePowerBalance` expression.

In this case, if the problem is now feasible, the user can check the solution of the variables `SystemBalanceSlackUp` and `SystemBalanceSlackDown`, and if one value is greater than zero, it represents that not enough generation (for Slack Up) or not enough demand (for Slack Down) in the optimization problem.

### Services cases

In many scenarios, certain units are also required to provide reserve requirements, e.g. thermal units mandated to provide up-regulation. In such scenarios, it is also possible to add slack variables, by specifying the service model (`RangeReserve`) for the specific service type (`VariableReserve{ReserveUp}`) as:
```julia
set_service_model!(
    template_uc,
    ServiceModel(
        VariableReserve{ReserveUp},
        RangeReserve;
        use_slacks=true
    ),
)
```
Again, if the problem is now feasible, check the solution of `ReserveRequirementSlack` variable, and if it is larger than zero in a specific time-step, then it is evidence that there is not enough reserve available to satisfy the requirement.

## Getting the infeasibility conflict

Some solvers allows to identify which constraints and variables are producing the infeasibility, by finding the irreducible infeasible set (IIS), that is the subset of constraints and variable bounds that will become feasible if any single constraint or variable bound is removed. 

To enable this feature in `PowerSimulations` the keyword argument `calculate_conflict` must be set to `true`, when creating the `DecisionModel`. Note that not all solvers allow the computation of the IIS, but most commercial solvers have this capability. It is also recommended to enable the keyword argument `store_variable_names=true` to help understanding which variables are with infeasibility issues.

The following code creates a decision model with the `Xpress` optimizer, and enabling the `calculate_conflict=true` keyword argument.

```julia
DecisionModel(
    template_ed,
    sys_rts_rt;
    name="ED",
    optimizer=optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 1e-2),
    optimizer_solve_log_print=true,
    calculate_conflict=true,
    store_variable_names=true,
)
```

Here is an example on how the IIS will be displayed as:

```raw
Error: Constraints participating in conflict basis (IIS) 
│ 
│ ┌──────────────────────────────────────┐
│ │ CopperPlateBalanceConstraint__System │
│ ├──────────────────────────────────────┤
│ │                            (113, 26) │
│ └──────────────────────────────────────┘
│ ┌──────────────────────────────────┐
│ │ EnergyAssetBalance__HybridSystem │
│ ├──────────────────────────────────┤
│ │               ("317_Hybrid", 26) │
│ └──────────────────────────────────┘
│ ┌─────────────────────────────────────────────┐
│ │ PieceWiseLinearCostConstraint__HybridSystem │
│ ├─────────────────────────────────────────────┤
│ │                          ("317_Hybrid", 26) │
│ └─────────────────────────────────────────────┘
│ ┌────────────────────────────────────────────────┐
│ │ PieceWiseLinearCostConstraint__ThermalStandard │
│ ├────────────────────────────────────────────────┤
│ │                            ("202_STEAM_3", 26) │
│ │                            ("101_STEAM_3", 26) │
│ │                               ("118_CC_1", 26) │
│ │                            ("202_STEAM_4", 26) │
│ │                               ("315_CT_6", 26) │
│ │                            ("201_STEAM_3", 26) │
│ │                            ("102_STEAM_4", 26) │
│ └────────────────────────────────────────────────┘
│ ┌──────────────────────────────────────────────────────────────────────┐
│ │ ActivePowerVariableTimeSeriesLimitsConstraint__RenewableDispatch__ub │
│ ├──────────────────────────────────────────────────────────────────────┤
│ │                                                   ("122_WIND_1", 26) │
│ │                                                     ("324_PV_3", 26) │
│ │                                                     ("312_PV_1", 26) │
│ │                                                     ("102_PV_1", 26) │
│ │                                                     ("101_PV_1", 26) │
│ │                                                     ("324_PV_2", 26) │
│ │                                                     ("313_PV_2", 26) │
│ │                                                     ("104_PV_1", 26) │
│ │                                                     ("101_PV_2", 26) │
│ │                                                   ("309_WIND_1", 26) │
│ │                                                     ("310_PV_2", 26) │
│ │                                                     ("113_PV_1", 26) │
│ │                                                     ("314_PV_1", 26) │
│ │                                                     ("324_PV_1", 26) │
│ │                                                     ("103_PV_1", 26) │
│ │                                                   ("303_WIND_1", 26) │
│ │                                                     ("314_PV_2", 26) │
│ │                                                     ("102_PV_2", 26) │
│ │                                                     ("314_PV_3", 26) │
│ │                                                     ("320_PV_1", 26) │
│ │                                                     ("101_PV_3", 26) │
│ │                                                     ("319_PV_1", 26) │
│ │                                                     ("314_PV_4", 26) │
│ │                                                     ("310_PV_1", 26) │
│ │                                                     ("215_PV_1", 26) │
│ │                                                     ("313_PV_1", 26) │
│ │                                                     ("101_PV_4", 26) │
│ │                                                     ("119_PV_1", 26) │
│ └──────────────────────────────────────────────────────────────────────┘
│ ┌─────────────────────────────────────────────────────────────────────────────┐
│ │ FeedforwardSemiContinousConstraint__ThermalStandard__ActivePowerVariable_ub │
│ ├─────────────────────────────────────────────────────────────────────────────┤
│ │                                                            ("322_CT_6", 26) │
│ │                                                            ("321_CC_1", 26) │
│ │                                                            ("223_CT_4", 26) │
│ │                                                            ("213_CT_1", 26) │
│ │                                                            ("223_CT_6", 26) │
│ │                                                            ("123_CT_1", 26) │
│ │                                                            ("113_CT_3", 26) │
│ │                                                            ("302_CT_3", 26) │
│ │                                                            ("215_CT_4", 26) │
│ │                                                            ("301_CT_4", 26) │
│ │                                                            ("113_CT_2", 26) │
│ │                                                            ("221_CC_1", 26) │
│ │                                                            ("223_CT_5", 26) │
│ │                                                            ("315_CT_7", 26) │
│ │                                                            ("215_CT_5", 26) │
│ │                                                            ("113_CT_1", 26) │
│ │                                                            ("307_CT_2", 26) │
│ │                                                            ("213_CT_2", 26) │
│ │                                                            ("113_CT_4", 26) │
│ │                                                            ("218_CC_1", 26) │
│ │                                                            ("213_CC_3", 26) │
│ │                                                            ("323_CC_2", 26) │
│ │                                                            ("322_CT_5", 26) │
│ │                                                            ("207_CT_2", 26) │
│ │                                                            ("123_CT_5", 26) │
│ │                                                            ("123_CT_4", 26) │
│ │                                                            ("207_CT_1", 26) │
│ │                                                            ("301_CT_3", 26) │
│ │                                                            ("302_CT_4", 26) │
│ │                                                            ("307_CT_1", 26) │
│ └─────────────────────────────────────────────────────────────────────────────┘
│ ┌───────────────────────────────────────────────────────┐
│ │ RenewableActivePowerLimitConstraint__HybridSystem__ub │
│ ├───────────────────────────────────────────────────────┤
│ │                                    ("317_Hybrid", 26) │
│ └───────────────────────────────────────────────────────┘
│ ┌───────────────────────────────────────┐
│ │ ThermalOnVariableUb__HybridSystem__ub │
│ ├───────────────────────────────────────┤
│ │                    ("317_Hybrid", 26) │
│ └───────────────────────────────────────┘

 Error: Serializing Infeasible Problem at /var/folders/1v/t69qyl0n5059n6c1nn7sp8zm7g8s6z/T/jl_jNSREb/compact_sim/problems/ED/infeasible_ED_2020-10-06T15:00:00.json
```

Note that the IIS clearly identify that the issue is happening at time step 26, and constraints are related with the `CopperPlateBalanceConstraint__System`, with multiple upper bound constraints, for the hybrid system, renewable units and thermal units. This highlights that there may not be enough generation in the system. Indeed, by enabling system slacks, the problem become feasible.

Finally, the infeasible model is exported in a `json` file that can be loaded directly in `JuMP` to be explored. More information about this is [available here](https://jump.dev/JuMP.jl/stable/moi/submodules/FileFormats/overview/#Read-from-file).
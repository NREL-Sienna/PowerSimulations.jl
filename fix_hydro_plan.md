# Plan: Include Pump Power in AreaPTDF Balances

## Finding

Issue #1661 is present in the current `PowerSimulations.jl` checkout when a
`PSY.HydroPumpTurbine` uses HydroPowerSimulations' `ActivePowerPumpVariable`
with `NetworkModel(AreaPTDFPowerModel)`.

The problem is in PowerSimulations.jl, not HydroPowerSimulations.jl:

- HydroPowerSimulations defines `ActivePowerPumpVariable <: PSI.VariableType`
  and passes it to `PSI.add_to_expression!` as part of its device-model
  construction.
- It does not define an `AreaPTDFPowerModel`-specific expression-insertion
  overload, so it correctly relies on PSI's shared network dispatch.
- PSI's specialized AreaPTDF insertion method in
  `src/devices_models/devices/common/add_to_expression.jl` accepts only
  `U <: ActivePowerVariable`.
- `ActivePowerPumpVariable` therefore falls back to PSI's generic
  `U <: VariableType` implementation, which adds it only to the
  `ActivePowerBalance` expression keyed by `PSY.ACBus`.
- Under `AreaPTDFPowerModel`, the balance constraints are instead built from
  the `PSY.Area` expression in `src/network_models/copperplate_model.jl`.
  The pump withdrawal affects PTDF flow calculations through the bus
  expression but is absent from the area-balance equality.

This lets a model build and solve with an unsupplied pumping withdrawal. The
resulting flows can look credible, which makes this a correctness defect rather
than a build-time failure.

## Implementation

1. Update the AreaPTDF-specific `add_to_expression!` method in
   `src/devices_models/devices/common/add_to_expression.jl`.
   - Keep its existing body, which writes each static-injection variable to
     both the `PSY.Area` and `PSY.ACBus` `ActivePowerBalance` containers.
   - Broaden only the variable-type bound from
     `U <: ActivePowerVariable` to `U <: VariableType`.
   - Do not add a HydroPowerSimulations-specific overload or a runtime type
     check. The method already carries the appropriate `PSY.StaticInjection`
     and formulation constraints, and the generic bound matches the sibling
     AreaBalance, CopperPlate, and PTDF expression-insertion methods.

2. Add a regression test in PowerSimulations.jl, where the faulty dispatch is
   owned and where `test/Project.toml` already includes HydroPowerSimulations.
   Prefer a focused testset in `test/test_network_constructors.jl`, adjacent to
   the existing two-area `AreaPTDFPowerModel` coverage.
   - Build a two-area system containing a `PSY.HydroPumpTurbine` configured
     with either `HydroPumpEnergyDispatch` or `HydroPumpEnergyCommitment`.
     The HydroPowerSimulations fixture
     `test/testing_utils.jl:build_hydro_with_both_pump_and_turbine` can supply
     the pump-turbine component; add/move the component into an existing
     two-area PSB system or construct an equivalent minimal two-area fixture.
   - Configure `ProblemTemplate(NetworkModel(AreaPTDFPowerModel))` with the
     hydro pump formulation and enough dispatchable generation/load to make
     pumping feasible.
   - Build the `DecisionModel`, retrieve `ActivePowerBalance` for `PSY.Area`
     and `PSY.ACBus`, and assert that the pump variable has a nonzero
     coefficient in both expressions at the pump's area/bus and a chosen time
     step. This is a direct, deterministic check of the original failure.
   - Solve the model and assert the area balance is satisfied while pump power
     is positive. Include pump power in the area accounting identity alongside
     generation, fixed load, and inter-area flow, using the same sign returned
     by `get_variable_multiplier(ActivePowerPumpVariable(), ...)`.
   - Cover both pump formulations when their constructors are available in the
     checked-out HydroPowerSimulations version. If only one currently builds,
     retain the direct expression test for its shared variable path and add the
     second formulation when its constructor support lands.

3. Add a small dispatch-level guard in the same testset if a full two-area
   hydro fixture becomes unnecessarily heavy.
   - Verify that `which(PSI.add_to_expression!, ...)` for
     `ActivePowerPumpVariable` plus `NetworkModel{AreaPTDFPowerModel}` resolves
     to the AreaPTDF method, not the bus-only generic fallback.
   - This check is supplementary, not a replacement for an expression or
     solve-level assertion, because method selection alone does not validate
     the two destination containers.

## Non-goals

- Do not modify `src/core/optimization_container.jl`; device expression
  routing is controlled by `add_to_expression!`, and the repository guidance
  explicitly prohibits changes to that orchestration layer.
- Do not add an HPS workaround. A downstream overload would duplicate PSI's
  network policy and leave other third-party `VariableType` static injections
  exposed to the same omission.
- Do not change PTDF flow construction or the area-balance constraint. Both
  consume the correct expression containers; the missing term is introduced
  earlier by method dispatch.

## Validation

1. Run the narrow regression file:

```powershell
julia --project=test test/runtests.jl test_network_constructors
```

2. Run the formatter after the Julia changes:

```powershell
julia --project=scripts/formatter -e 'include("scripts/formatter/formatter_code.jl")'
```

3. Run the full test suite before merging because the broadened method applies
   to every `VariableType` static injection under AreaPTDF:

```powershell
julia --project=test test/runtests.jl
```

## Acceptance Criteria

- A pump variable is present in both the area and nodal active-power-balance
  expressions under `AreaPTDFPowerModel`.
- The pump withdrawal enters the correct area's equality constraint with its
  existing multiplier/sign.
- A feasible pump dispatch cannot solve without corresponding area supply.
- Existing AreaPTDF network, storage, and non-AreaPTDF tests remain green.
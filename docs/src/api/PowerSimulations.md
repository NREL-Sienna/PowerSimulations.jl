```@meta
CurrentModule = PowerSimulations
DocTestSetup  = quote
    using PowerSimulations
end
```

# Device Models

List of structures and methods for Device models

```@docs
DeviceModel
```

### Formulations

Refer to the Formulations Page for each Abstract Device Formulation.

# Decision Models

```@docs
DecisionModel
build!(::DecisionModel)
solve!(::DecisionModel)
```
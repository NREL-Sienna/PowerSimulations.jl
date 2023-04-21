```@meta
CurrentModule = PowerSimulations
DocTestSetup  = quote
    using PowerSimulations
end
```

# API Reference


### Table of Contents

1. [Device Models](#Device-Models)
2. [Decision Models](#Decision-Models)



# Device Models

List of structures and methods for Device models

```@docs
DeviceModel
```

### Formulations

Refer to the [Formulations Page](https://nrel-siip.github.io/PowerSimulations.jl/latest/formulation_library/General/) for each Abstract Device Formulation.

```@raw html
&nbsp;
&nbsp;
```

# Decision Models

```@docs
DecisionModel
DecisionModel(::Type{M} where {M <: DecisionProblem}, ::ProblemTemplate, ::PSY.System, ::Union{Nothing, JuMP.Model}) 
DecisionModel(::AbstractString, ::MOI.OptimizerWithAttributes)
build!(::DecisionModel)
solve!(::DecisionModel)
```
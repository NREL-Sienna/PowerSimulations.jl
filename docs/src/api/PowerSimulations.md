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
3. [Emulation Models](#Emulation-Models)


# Device Models

List of structures and methods for Device models

```@docs
DeviceModel
```

### Formulations

Refer to the [Formulations Page](https://nrel-siip.github.io/PowerSimulations.jl/latest/formulation_library/General/) for each Abstract Device Formulation.

### Problem Templates

Refer to the [Problem Templates Page](https://nrel-siip.github.io/PowerSimulations.jl/latest/modeler_guide/problem_templates/) for available `ProblemTemplate`s.

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

```@raw html
&nbsp;
&nbsp;
```

# Emulation Models

```@docs
EmulationModel
EmulationModel(::Type{M} where {M <: EmulationProblem}, ::ProblemTemplate, ::PSY.System, ::Union{Nothing, JuMP.Model})
EmulationModel(::AbstractString, ::MOI.OptimizerWithAttributes)
build!(::EmulationModel)
run!(::EmulationModel)
```
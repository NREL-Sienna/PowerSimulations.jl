# `Source` Formulations

Source formulations define the optimization models that describe source or infinite bus units mathematical model in different operational settings, such as economic dispatch and unit commitment.

!!! note
    
    The use of reactive power variables and constraints will depend on the network model used, i.e., whether it uses (or does not use) reactive power. If the network model is purely active power-based,  reactive power variables and related constraints are not created.

!!! note
    
    Reserve variables for services are not included in the formulation, albeit their inclusion change the variables, expressions, constraints and objective functions created. A detailed description of the implications in the optimization models is described in the [Service formulation](@ref service_formulations) section.

### Table of Contents

 1. [`ImportExportSourceModel`](#ImportExportSourceModel)

* * *

## `ImportExportSourceModel`

```@docs
ImportExportSourceModel
```

TODO

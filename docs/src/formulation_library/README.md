# Formulation documentation guide

Formulation documentation should *roughly* follow the template established by RenewableGen.md

## Auto generated items

- Valid DeviceModel table: just change the device category in the filter function
- Time Series Parameters: just change the device category and formulation in the `get_defualt_time_series_names` method call


## Linked items

- Formulations in the Valid DeviceModel table must have a docstring in src/core/formulations.jl
- The Formulation in the @docs block must have a docstring in src/core/formulations.jl
- The Variables must have docstrings in src/core/variables.jl 
- The Time Series Paraemters must have docstrings in src/core/paramters.jl

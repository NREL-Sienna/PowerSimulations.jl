# PowerSimulations

```@meta
CurrentModule = PowerSimulations
DocTestSetup  = quote
    using PowerSimulations
end
```

API documentation

```@contents
Pages = ["PowerSimulations.md"]
```

## Index

```@index
Pages = ["PowerSimulations.md"]
```

## Exported

```@autodocs
Modules = [PowerSimulations]
Private = false
Filter = t -> typeof(t) === DataType ? !(t <: Union{PowerSimulations.AbstractDeviceFormulation, PowerSimulations.AbstractServiceFormulation}) : true
```

## Internal

```@autodocs
Modules = [PowerSimulations]
Public = false
```

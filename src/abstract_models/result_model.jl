mutable struct PowerResults
    ThermalGeneration::Union{Nothing,DataFrames.DataFrame}
    RenewableGEneration::Union{Nothing,DataFrames.DataFrame}
    HydroGeneration::Union{Nothing,DataFrames.DataFrame}
    Storage::Union{Nothing,DataFrames.DataFrame}
    Load::Union{Nothing,DataFrames.DataFrame}
    SolverOutput::Union{Nothing,Dict}
end

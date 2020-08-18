"""
Return a SimulationStore.
"""
function make_simulation_store(directory::AbstractString)
    return HdfSimulationStore(directory; create = true)
end

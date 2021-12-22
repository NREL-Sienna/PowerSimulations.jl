"""
Provides storage of simulation data
"""
abstract type SimulationStore end

# Required methods:
# - open_store
# - Base.isopen(store::SimulationStore)
# - Base.close(store::SimulationStore)
# - Base.flush(store::SimulationStore)
# - get_params(store::SimulationStore)
# - initialize_problem_storage!
# - list_fields(store::SimulationStore, problem::Symbol, container_type::Symbol)
# - list_problems(store::SimulationStore)
# - log_cache_hit_percentages(store::SimulationStore)
# - write_result!
# - read_result!
# - write_optimizer_stats!
# - read_problem_optimizer_stats

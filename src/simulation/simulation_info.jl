mutable struct SimulationInfo
    number::Union{Nothing, Int}
    sequence_uuid::Union{Nothing, Base.UUID}
    run_status::RunStatus
end

SimulationInfo() = SimulationInfo(nothing, nothing, RunStatus.INITIALIZED)

get_number(si::SimulationInfo) = si.number
set_number!(si::SimulationInfo, val::Int) = si.number = val
get_sequence_uuid(si::SimulationInfo) = si.sequence_uuid
set_sequence_uuid!(si::SimulationInfo, val::Base.UUID) = si.sequence_uuid = val
get_run_status(si::SimulationInfo) = si.run_status
set_run_status!(si::SimulationInfo, val::RunStatus) = si.run_status = val

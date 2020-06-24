abstract type VariableType end
struct ActivePowerVariable <: VariableType end
struct ReactivePowerVariable <: VariableType end
struct CommitmentVariable <: VariableType end
struct EnergyVariable <: VariableType end
struct EnergyStorageVariable <: VariableType end
struct RegulationServiceVariable <: VariableType end
struct ServiceVariable <: VariableType end
struct SpillageVariable <: VariableType end
struct StorageReservationVariable <: VariableType end

abstract type Chronology end

struct Synchronize <: Chronology
    from_steps::Int64
    to_steps::Int64
end

struct RecedingHorizon <: Chronology end

struct Sequential <: Chronology end

abstract type Chronology end

struct Synchronize <: Chronology end
struct RecedingHorizon <: Chronology end
struct Sequential <: Chronology end

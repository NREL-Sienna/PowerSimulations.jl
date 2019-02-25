abstract type AbstractServiceFormulation end

abstract type AbstractReservesForm <: AbstractServiceFormulation end

abstract type AbstractRegulationReserveForm <: AbstractReservesForm end

struct RampLimitedReserve <: AbstractReservesForm end
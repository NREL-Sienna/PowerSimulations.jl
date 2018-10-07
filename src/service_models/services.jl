abstract type AbstractServiceForm end 

abstract type AbstractReservesForm <: AbstractServiceForm end

abstract type AbstractRegulationReserveForm <: AbstractReservesForm end

struct RampLimitedReserve <: AbstractReservesForm end
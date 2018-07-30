abstract type NetworkType end

abstract type RealNetwork <: NetworkType end

abstract type CopperPlate <: NetworkType end

abstract type NetworkFlow <: NetworkType end
abstract type DCPowerFlow <: NetworkType end
abstract type ACPowerFlow <: NetworkType end


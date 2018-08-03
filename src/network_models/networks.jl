abstract type NetworkType end

abstract type RealNetwork <: NetworkType end

abstract type CopperPlate <: RealNetwork end

abstract type NetworkFlow <: RealNetwork end
abstract type DCPowerFlow <: RealNetwork end
abstract type ACPowerFlow <: NetworkType end


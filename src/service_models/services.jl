abstract type AbstractServiceFormulation end

abstract type AbstractReservesFormulation<:AbstractServiceFormulation end

abstract type AbstractRegulationReserveFormulation<:AbstractReservesFormulation end

struct RampLimitedReserve<:AbstractReservesFormulation end

struct LoadProportionalReserve<:AbstractReservesFormulation end

struct ServiceMap
    thermal::Dict{Base.UUID,PSY.ThermalGen}
    hydro::Dict{Base.UUID,PSY.HydroGen}
    re::Dict{Base.UUID,PSY.RenewableGen}
    storage::Dict{Base.UUID,PSY.Storage}  
end

function ServiceMap()
    return ServiceMap1(Dict{Base.UUID,PSY.ThermalGen}(),
            Dict{Base.UUID,PSY.HydroGen}(),
            Dict{Base.UUID,PSY.RenewableGen}(),
            Dict{Base.UUID,PSY.Storage}())
end

add_device(smap::ServiceMap, d::PSY.ThermalGen) =smap.thermal[IS.getuuid(d)] = d
add_device(smap::ServiceMap, d::PSY.HydroGen) = smap.hydro[IS.get_uuid(d)] = d
add_device(smap::ServiceMap, d::PSY.RenewableGen) = smap.re[IS.get_uuid(d)] = d
add_device(smap::ServiceMap, d::PSY.Storage) = smap.storage[IS.get_uuid(d)] = d

get_fields(smap::ServiceMap) = [smap.thermal,smap.hydro,smap.re,smap.storage]


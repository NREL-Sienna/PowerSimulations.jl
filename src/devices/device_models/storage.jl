abstract type AbstractStorageForm <: AbstractDeviceFormulation end

abstract type BookKeepingModel <: AbstractStorageForm end

include("storage/storage_variables.jl")
include("storage/output_constraints.jl")
include("storage/book_keeping_constraints.jl")
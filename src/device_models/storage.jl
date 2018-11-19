abstract type AbstractStorageForm end

abstract type BookKeepingForm <: AbstractStorageForm end

abstract type PowerModelsForm <: AbstractStorageForm end

include("storage/storage_variables.jl")
include("storage/output_constraints.jl")
include("storage/book_keeping_constraints.jl")
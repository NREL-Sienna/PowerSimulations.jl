abstract type AbstractStorageForm end

abstract type BookKeepingForm <: AbstractStorageForm end

include("storage/storage_variables.jl")
include("storage/book_keeping_constraints.jl")
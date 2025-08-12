# If `ixs` does not index all dimensions of `dest`, add a `:` for the rest (like Python's
# `...`) to prepare for broadcast-assigning.
function expand_ixs(ixs::NTuple{1, T}, dest::AbstractArray) where {T}
    if length(ixs) <= ndims(dest)
        return (ixs[1], fill(:, ndims(dest) - 1)...)
    else
        throw(ArgumentError("`ixs` must not index more dimensions than `dest` has"))
    end
end

function expand_ixs(ixs::Tuple{T, U}, dest::AbstractArray) where {T, U}
    if length(ixs) <= ndims(dest)
        return (ixs[1], fill(:, ndims(dest) - 2)..., ixs[end])
    else
        throw(ArgumentError("`ixs` must not index more dimensions than `dest` has"))
    end
end

function expand_ixs(ixs::Tuple, dest::AbstractArray)
    if length(ixs) <= ndims(dest)
        return (ixs[1:(end - 1)]..., fill(:, ndims(dest) - length(ixs))..., ixs[end])
    else
        throw(ArgumentError("`ixs` must not index more dimensions than `dest` has"))
    end
end

function assign_expand(dest::AbstractArray, src, ixs::Tuple)
    dest[expand_ixs(ixs, dest)...] .= src
    return
end
# If `src` is an array, broadcast across it to perform the assignment
assign_maybe_broadcast!(dest::AbstractArray, src::AbstractArray, ixs::Tuple) =
    assign_expand(dest, src, ixs)
# If `src` is a tuple or scalar, do not broadcast across it (may still broadcast across `dest`)
assign_maybe_broadcast!(dest::AbstractArray, src, ixs::Tuple) =
    assign_expand(dest, Ref(src), ixs)

# Same as assign_expand, assign_maybe_broadcast! but for fixing JuMP VariableRefs
fix_expand(dest::AbstractArray, src, ixs::Tuple) =
    fix_parameter_value.(dest[expand_ixs(ixs, dest)...], src)
fix_maybe_broadcast!(dest::AbstractArray, src::AbstractArray, ixs::Tuple) =
    fix_expand(dest, src, ixs)
fix_maybe_broadcast!(dest::AbstractArray, src, ixs::Tuple) =
    fix_expand(dest, Ref(src), ixs)

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

# If `src` is an array, we want to set a slice of `dest` equal to `src`. Broadcast
# assignment from integer-indexed `src` to DenseAxisArray `dest` slice of same shape doesn't
# work when `dest`'s axes being broadcast across aren't 1:n, but standard assignment does
# the trick in that case and (PERF) seems to not appreciably affect simulation performance
function assign_maybe_broadcast!(dest::AbstractArray, src::AbstractArray, ixs::Tuple)
    expanded_axs = expand_ixs(ixs, dest)
    dest[expanded_axs...] = src
    return
end

# If `src` is a tuple or scalar, we want to set all values across a slice of `dest` equal to `src`
function assign_maybe_broadcast!(dest::AbstractArray, src, ixs::Tuple)
    expanded_axs = expand_ixs(ixs, dest)
    dest[expanded_axs...] .= Ref(src)
    return
end

# Similar to assign_maybe_broadcast! but for fixing JuMP VariableRefs
fix_expand(dest::AbstractArray, src, ixs::Tuple) =
    fix_parameter_value.(dest[expand_ixs(ixs, dest)...], src)
fix_maybe_broadcast!(dest::AbstractArray, src::AbstractArray, ixs::Tuple) =
    fix_expand(dest, src, ixs)
fix_maybe_broadcast!(dest::AbstractArray, src, ixs::Tuple) =
    fix_expand(dest, Ref(src), ixs)

function check_kwargs(input_kwargs, valid_set::Array{Symbol}, function_name::String)
    if isempty(input_kwargs)
        return
    else
        for (key, value) in input_kwargs
            if !(key in valid_set)
                throw(ArgumentError("keyword argument $(key) is not a valid input for $(function_name)"))
        end
    end
    return
end

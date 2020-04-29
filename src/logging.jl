"""
    configure_logging(;
        console_level = Error,
        file_level = Info,
        filename = "power-simulations.log",
    )

Creates console and file loggers.

**Note:** Log messages may not be written to the file until flush() or close() is called on
the returned logger.

# Arguments
- `console_level = Error`: level for console messages
- `file_level = Info`: level for file messages
- `filename::String = power-simulations.log`: log file

# Example
```julia
logger = configure_logging(console_level = Info)
@info "log message"
close(logger)
```
"""
function configure_logging(;
    console_level = Logging.Error,
    file_level = Logging.Info,
    filename = "power-simulations.log",
)
    return IS.configure_logging(
        console = true,
        console_stream = stderr,
        console_level = console_level,
        file = true,
        filename = filename,
        file_level = file_level,
        file_mode = "w+",
        tracker = nothing,
        set_global = true,
    )
end

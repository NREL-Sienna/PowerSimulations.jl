# Modeling FAQ

!!! question "How do I reduce the amount of print on my REPL?"
    
    The print to the REPL is controlled with the logging. Check the [Logging](@ref) documentation page to see how to reduce the print out

!!! question "How do I print the optimizer logs to see the solution process?"
    
    When specifying the `DecisionModel` or `EmulationModel` pass the keyword `print_optimizer_log = true`

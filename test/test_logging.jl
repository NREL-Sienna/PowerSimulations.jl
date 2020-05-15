@testset "Test configure_logging" begin
    logfile = "testlog.txt"
    msg = "test log message"
    orig = Logging.global_logger()
    logger = configure_logging(; filename = logfile)

    try
        with_logger(logger) do
            @info msg
        end

        close(logger)

        @test isfile(logfile)
        open(logfile) do io
            lines = readlines(io)
            @test length(lines) == 2  # two lines per message
            @test occursin(msg, lines[1])
        end
    finally
        rm(logfile)
        Logging.global_logger(orig)
    end
end

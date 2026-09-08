@testset "align_to_dataset_grid" begin
    grid_start = DateTime("2024-01-01T00:00:00")
    resolution = Millisecond(Hour(1))
    dataset = PSI.InMemoryDataset(0.0, grid_start, resolution, 0, 5, ["gen"])

    # on-grid timestamps are fixed points
    on_grid = DateTime("2024-01-01T02:00:00")
    @test PSI.align_to_dataset_grid(dataset, on_grid) == on_grid
    @test PSI.find_aligned_timestamp_index(dataset, on_grid) == 3

    # off-grid timestamps floor to the containing row
    @test PSI.align_to_dataset_grid(dataset, DateTime("2024-01-01T00:05:00")) == grid_start
    @test PSI.align_to_dataset_grid(dataset, DateTime("2024-01-01T00:59:00")) == grid_start
    @test PSI.align_to_dataset_grid(dataset, DateTime("2024-01-01T01:00:00")) ==
          DateTime("2024-01-01T01:00:00")
    @test PSI.find_aligned_timestamp_index(dataset, DateTime("2024-01-01T00:05:00")) == 1
    @test PSI.find_aligned_timestamp_index(dataset, DateTime("2024-01-01T00:59:00")) == 1
    @test PSI.find_aligned_timestamp_index(dataset, DateTime("2024-01-01T01:00:00")) == 2

    # a timestamp before the grid start has no containing row
    @test_throws ErrorException PSI.align_to_dataset_grid(
        dataset,
        DateTime("2023-12-31T23:00:00"),
    )
end

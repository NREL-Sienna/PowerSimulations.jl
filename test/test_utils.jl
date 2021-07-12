@testset "test key with value" begin
    d = Dict("foo" => "bar")
    @test_throws ErrorException PSI.find_key_with_value(d, "fake")
end

@testset "dense axis to dataframe" begin
    one = JuMP.Containers.DenseAxisArray{Float64}(undef, 1:2)
    fill!(one, 1.0)
    one_df = PSI.axis_array_to_dataframe(one, [:name])
    test_df = DataFrames.DataFrame(:name => [1.0, 1.0])
    @test one_df == test_df
    three = JuMP.Containers.DenseAxisArray{Float64}(undef, [:a], 1:2, 1:3)
    fill!(three, 1.0)
    three_df = PSI.axis_array_to_dataframe(three)
    test_df = DataFrames.DataFrame(
        :S1 => [1.0, 1.0, 1.0, 2.0, 2.0, 2.0],
        :a => [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
    )
    @test three_df == test_df
    four = JuMP.Containers.DenseAxisArray{Float64}(undef, [:a], 1:2, 1:3, 1:5)
    @test_throws ErrorException PSI.axis_array_to_dataframe(four)

    three_int = JuMP.Containers.DenseAxisArray{Int}(undef, [:a], 1:2, 1:3)
    fill!(three_int, 2)
    three_df = PSI.axis_array_to_dataframe(three_int)
    test_df = DataFrames.DataFrame(
        :S1 => [1.0, 1.0, 1.0, 2.0, 2.0, 2.0],
        :a => [2.0, 2.0, 2.0, 2.0, 2.0, 2.0],
    )
    @test three_df == test_df
    four = JuMP.Containers.DenseAxisArray{Int}(undef, [:a], 1:2, 1:3, 1:5)
    fill!(four, 2)
    @test isempty(PSI.axis_array_to_dataframe(four))
end

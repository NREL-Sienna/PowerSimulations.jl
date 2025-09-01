@testset "to_dataframe with DenseAxisArray 1D" begin
    data = rand(3)
    array = DenseAxisArray(data, 1:3)
    key = PSI.VariableKey(PSI.ActivePowerVariable, PSY.ThermalStandard)
    df = PSI.to_dataframe(array, key)

    @test size(df) == (3, 1)
    @test names(df) == ["ActivePowerVariable__ThermalStandard"]
    @test df[!, "ActivePowerVariable__ThermalStandard"] == data
end

@testset "to_dataframe with DenseAxisArray 2D" begin
    data = rand(2, 3)
    components = ["component1", "component2"]
    array = DenseAxisArray(data, components, 1:3)
    key = PSI.VariableKey(PSI.ActivePowerVariable, PSY.ThermalStandard)
    df = PSI.to_dataframe(array, key)

    @test size(df) == (3, 2)
    @test names(df) == components
    @test df[!, "component1"] == permutedims(data)[:, 1]
    @test df[!, "component2"] == permutedims(data)[:, 2]
end

@testset "to_results_dataframe with 2D DenseAxisArray - LONG format with timestamps" begin
    data = rand(2, 3)
    components = ["component1", "component2"]
    array = DenseAxisArray(data, components, 1:3)
    timestamps = [
        DateTime(2024, 1, 1, 0),
        DateTime(2024, 1, 1, 1),
        DateTime(2024, 1, 1, 2),
    ]
    df = PSI.to_results_dataframe(array, timestamps, Val(IS.TableFormat.LONG))

    @test size(df) == (6, 3)  # 2 components × 3 timestamps = 6 rows, 3 columns
    @test names(df) == ["DateTime", "component", "value"]
    @test df.DateTime == repeat(timestamps, 2)
    @test df.component == repeat(components; inner = 3)
    @test df.value == reshape(permutedims(data), 6)

    # Test error with mismatched timestamps.
    wrong_timestamps = [DateTime(2024, 1, 1, 1)]
    @test_throws ErrorException PSI.to_results_dataframe(
        array, wrong_timestamps, Val(IS.TableFormat.LONG),
    )
end

@testset "to_results_dataframe with 2D DenseAxisArray - LONG format without timestamps" begin
    data = rand(2, 3)
    components = ["component1", "component2"]
    array = DenseAxisArray(data, components, 1:3)
    df = PSI.to_results_dataframe(array, nothing, Val(IS.TableFormat.LONG))

    @test size(df) == (6, 3)  # 2 components × 3 timestamps = 6 rows, 3 columns
    @test names(df) == ["time_index", "component", "value"]
    @test df.time_index == repeat([1, 2, 3], 2)
    @test df.component == repeat(components; inner = 3)
    @test df.value == reshape(permutedims(data), 6)
end

@testset "to_results_dataframe with 2D DenseAxisArray - WIDE format with timestamps" begin
    data = rand(2, 3)
    components = ["component1", "component2"]
    array = DenseAxisArray(data, components, 1:3)
    timestamps = [
        DateTime(2024, 1, 1, 0),
        DateTime(2024, 1, 1, 1),
        DateTime(2024, 1, 1, 2),
    ]
    df = PSI.to_results_dataframe(array, timestamps, Val(IS.TableFormat.WIDE))

    @test size(df) == (3, 3)  # 3 timestamps, 3 columns (DateTime + 2 components)
    @test names(df) == ["DateTime", "component1", "component2"]
    @test df.DateTime == timestamps
    exp_data = permutedims(data)
    @test df.component1 == exp_data[:, 1]
    @test df.component2 == exp_data[:, 2]
end

@testset "to_results_dataframe with 2D DenseAxisArray - WIDE format without timestamps" begin
    data = rand(2, 3)
    components = ["component1", "component2"]
    array = DenseAxisArray(data, components, 1:3)
    df = PSI.to_results_dataframe(array, nothing, Val(IS.TableFormat.WIDE))

    @test size(df) == (3, 3)  # 3 timestamps, 3 columns (DateTime + 2 components)
    @test names(df) == ["time_index", "component1", "component2"]
    @test df.time_index == [1, 2, 3]
    exp_data = permutedims(data)
    @test df.component1 == exp_data[:, 1]
    @test df.component2 == exp_data[:, 2]
end

function _fill_3d_data()
    components = ["component1", "component2"]
    extra = ["1", "2", "3", "4"]
    array = DenseAxisArray(zeros(2, 4, 3), components, extra, 1:3)
    array["component1", "1", :] = [1.0, 2.0, 3.0]
    array["component1", "2", :] = [2.0, 3.0, 4.0]
    array["component1", "3", :] = [3.0, 4.0, 5.0]
    array["component1", "4", :] = [6.0, 7.0, 8.0]
    array["component2", "1", :] = [11.0, 12.0, 13.0]
    array["component2", "2", :] = [12.0, 13.0, 14.0]
    array["component2", "3", :] = [13.0, 14.0, 15.0]
    array["component2", "4", :] = [16.0, 17.0, 18.0]
    return array
end

function _check_3d_data(df)
    @test size(df) == (24, 4)  # 2 components x 4 extra × 3 timestamps = 24 rows, 4 columns
    @test @rsubset(df, :component == "component1" && :component_x == "1")[!, :value] ==
          [1.0, 2.0, 3.0]
    @test @rsubset(df, :component == "component1" && :component_x == "2")[!, :value] ==
          [2.0, 3.0, 4.0]
    @test @rsubset(df, :component == "component1" && :component_x == "3")[!, :value] ==
          [3.0, 4.0, 5.0]
    @test @rsubset(df, :component == "component1" && :component_x == "4")[!, :value] ==
          [6.0, 7.0, 8.0]
    @test @rsubset(df, :component == "component2" && :component_x == "1")[!, :value] ==
          [11.0, 12.0, 13.0]
    @test @rsubset(df, :component == "component2" && :component_x == "2")[!, :value] ==
          [12.0, 13.0, 14.0]
    @test @rsubset(df, :component == "component2" && :component_x == "3")[!, :value] ==
          [13.0, 14.0, 15.0]
    @test @rsubset(df, :component == "component2" && :component_x == "4")[!, :value] ==
          [16.0, 17.0, 18.0]
end

@testset "to_results_dataframe with 3D DenseAxisArray - LONG format with timestamps" begin
    array = _fill_3d_data()
    timestamps = [
        DateTime(2024, 1, 1, 0),
        DateTime(2024, 1, 1, 1),
        DateTime(2024, 1, 1, 2),
    ]
    df = PSI.to_results_dataframe(array, timestamps, Val(IS.TableFormat.LONG))
    _check_3d_data(df)

    # Test error with mismatched timestamps.
    wrong_timestamps = [DateTime(2024, 1, 1, 1)]
    @test_throws ErrorException PSI.to_results_dataframe(
        array, wrong_timestamps, Val(IS.TableFormat.LONG),
    )
end

@testset "to_results_dataframe with 3D DenseAxisArray - LONG format without timestamps" begin
    array = _fill_3d_data()
    df = PSI.to_results_dataframe(array, nothing, Val(IS.TableFormat.LONG))
    @test names(df) == ["time_index", "component", "component_x", "value"]
    _check_3d_data(df)
    @test df.time_index == repeat([1, 2, 3], 8)
end

ps_model = PSI.CanonicalModel(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.AbstractVariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 5, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 5, 24)),
                              Dict{String,Any}(),
                              nothing);

ps_model = canonical_model_test(); PSI.activepower_variables(ps_model, generators5, 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 120
ps_model = canonical_model_test(); PSI.reactivepower_variables(ps_model, generators5, 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 120
ps_model = canonical_model_test(); PSI.commitment_variables(ps_model, generators5, 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 360

ps_model = canonical_model_test(); PSI.activepower_variables(ps_model, renewables, 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 72
ps_model = canonical_model_test(); PSI.reactivepower_variables(ps_model, renewables , 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 72

ps_model = canonical_model_test(); PSI.activepower_variables(ps_model, generators_hg, 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 48
ps_model = canonical_model_test(); PSI.reactivepower_variables(ps_model, generators_hg , 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 48

ps_model = canonical_model_test(); PSI.activepower_variables(ps_model, battery, 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 48
ps_model = canonical_model_test(); PSI.reactivepower_variables(ps_model, battery , 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 24
ps_model = canonical_model_test(); PSI.energystorage_variables(ps_model, battery , 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 24
ps_model = canonical_model_test(); PSI.storagestate_variables(ps_model, battery , 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 24
ps_model = canonical_model_test(); PSI.activepower_variables(ps_model, loads5_DA, 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 72
ps_model = canonical_model_test(); PSI.reactivepower_variables(ps_model, loads5_DA, 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 72

ps_model = canonical_model_test(); PSI.flow_variables(ps_model, PM.DCPlosslessForm, branches5, 1:24); @test JuMP.num_variables(ps_model.JuMPmodel) == 144

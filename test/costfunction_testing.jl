ps_model = PSI.CanonicalModel(Model(),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, 14, 24),
                                                                         "var_reactive" => PSI.JumpAffineExpressionArray(undef, 14, 24)),
                              Dict());

@test try   PSI.activepowervariables(ps_model, generators5, 1:24); 
            PSI.cost_function(ps_model, generators5, PSI.ThermalDispatch, PM.DCPlosslessForm); 
            true 
    finally end

@test try   PSI.commitmentvariables(ps_model, generators5, 1:24); 
            PSI.cost_function(ps_model, generators5, PSI.StandardThermalCommitment, PM.DCPlosslessForm); 
            true 
    finally end

@test try   PSI.activepowervariables(ps_model, renewables, 1:24); 
            PSI.cost_function(ps_model, renewables, PSI.RenewableFullDispatch, PM.DCPlosslessForm); 
            true 
    finally end

#=



@test try PSI.activepowervariables(ps_model, generators_hg, 1:24); true finally end
@test try PSI.reactivepowervariables(ps_model, generators_hg , 1:24); true finally end

@test try PSI.activepowervariables(ps_model, battery, 1:24); true finally end
@test try PSI.reactivepowervariables(ps_model, battery , 1:24); true finally end

@test try PSI.activepowervariables(ps_model, loads5_DA, 1:24); true finally end
@test try PSI.reactivepowervariables(ps_model, loads5_DA, 1:24); true finally end

@test try PSI.flowvariables(ps_model, PM.DCPlosslessForm, branches5, 1:24); true finally end
=#
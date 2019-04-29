
mutable struct Incumbent 
    variable_value                  ::Vector{Float64}
    objective_value                 ::Float64 
    best_bound                      ::Float64 
    status                          ::MOI.TerminationStatusCode 
end

Incumbent() = Incumbent(Vector{Float64}(), NaN, NaN, MOI.OPTIMIZE_NOT_CALLED)

mutable struct Status 
    local_solve_status              ::MOI.TerminationStatusCode 
    mip_solve_status                ::MOI.TerminationStatusCode
    alpine_status                   ::MOI.TerminationStatusCode
    bt_status                       ::MOI.TerminationStatusCode
end 

Status() = Status(MOI.OPTIMIZE_NOT_CALLED, MOI.OPTIMIZE_NOT_CALLED, 
    MOI.OPTIMIZE_NOT_CALLED, MOI.OPTIMIZE_NOT_CALLED)

mutable struct SolverOptions 
    nlp_optimizer                   ::Union{Nothing, MOI.AbstractOptimizer}
    minlp_optimizer                 ::Union{Nothing, MOI.AbstractOptimizer}
    mip_optimizer                   ::Union{Nothing, MOI.AbstractOptimizer}
    
    log_level                       ::Int 
    time_limit                      ::Float64 
    max_iter                        ::Int 
    rel_gap                         ::Float64 
    abs_gap                         ::Float64 
    opt_tol                         ::Float64 
    
    disc_partition_method           ::Symbol 
    disc_ratio                      ::Float64 
    disc_uniform_rate               ::Float64 
    disc_divert_chunks              ::Int 
    disc_abs_width_tol              ::Float64 
    disc_rel_width_tol              ::Float64 
    disc_consecutive_forbid         ::Int 

    bt                              ::Bool 
    presolve_time_limit             ::Float64 
    bt_max_iter                     ::Int 
    bt_width_tol                    ::Float64
    bt_improvement_tol              ::Float64 
    bt_precision                    ::Int 
    bt_algo                         ::Symbol 
    bt_relax                        ::Bool 
    bt_mip_time_limit               ::Float64 
    bp                              ::Bool 
    bp_max_iter                     ::Int

    is_problem_convex               ::Bool
    perform_bp_only                 ::Bool 
    perform_bounding_solve_only     ::Bool

    max_multistart_points           ::Int
end 

get_nlp_optimizer(model::MOI.AbstractOptimizer)::Union{Nothing, MOI.AbstractOptimizer} = model.solver_options.nlp_optimizer  

get_mip_optimizer(model::MOI.AbstractOptimizer)::Union{Nothing, MOI.AbstractOptimizer} = model.solver_options.mip_optimizer 

get_minlp_optimizer(model::MOI.AbstractOptimizer)::Union{Nothing, MOI.AbstractOptimizer} = model.solver_options.minlp_optimizer


mutable struct VariableInfo
    lower_bound::Float64  # May be -Inf even if has_lower_bound == true
    has_lower_bound::Bool # Implies lower_bound == Inf
    upper_bound::Float64  # May be Inf even if has_upper_bound == true
    has_upper_bound::Bool # Implies upper_bound == Inf
    is_fixed::Bool        # Implies lower_bound == upper_bound and !has_lower_bound and !has_upper_bound
    is_binary::Bool       # Implies lower_bound == 0, upper_bound == 1 and is MOI.ZeroOne
    is_integer::Bool      # true if variable is MOI.Integer
    is_bounded::Bool      # has_lower_bound == true && has_upper_bound == true 
    is_in_nl_term::Bool   # true if the variable is a part of some non-linear term 
    name::String
    start::Union{Nothing, Float64}
end

VariableInfo() = VariableInfo(-Inf, false, Inf, false, false, false, false, false, false, "", nothing)

function info_array_of_variables(variable_info::Vector{VariableInfo}, attr::Symbol)
    len_var_info = length(variable_info)
    type_dict = get_type_dict(variable_info[1])
    result = Array{type_dict[attr], 1}(undef, len_var_info)
    for i = 1:len_var_info
        result[i] = getfield(variable_info[i], attr)
    end
    return result
end

mutable struct TermInfo 
    lifted_variable_id              ::Int 
    convexity                       ::Symbol
    lifted_variable_info            ::VariableInfo 
    term_type                       ::Union{Nothing, Symbol}
    in_constraint                   ::Union{Nothing, Dict{Symbol, Any}}
end 

TermInfo() = TermInfo(NaN, :undet, VariableInfo(), nothing, nothing)
    
mutable struct Terms 
    quadratic_terms                 ::Union{Nothing, Dict{Expr, TermInfo}}
    power_terms                     ::Union{Nothing, Dict{Expr, TermInfo}}
    bilinear_terms                  ::Union{Nothing, Dict{Expr, TermInfo}}
    multilinear_terms               ::Union{Nothing, Dict{Expr, TermInfo}}
    abs_terms                       ::Union{Nothing, Dict{Expr, TermInfo}}
    trigonometric_terms             ::Union{Nothing, Dict{Expr, TermInfo}}
    log_terms                       ::Union{Nothing, Dict{Expr, TermInfo}}
    exp_terms                       ::Union{Nothing, Dict{Expr, TermInfo}}
    other_terms                     ::Union{Nothing, Dict{Expr, TermInfo}}
end 

Terms() = Terms(nothing, nothing, nothing, nothing, 
    nothing, nothing, nothing, nothing, nothing)

mutable struct AlpineExpr 
    expression                      ::Tuple{Float64, Union{Expr, Symbol, Float64, Int}} 
    convexity                       ::Symbol
end 

mutable struct NLFunction 
    linear_part                     ::Union{Nothing, Vector{AlpineExpr}}
    quadratic_part                  ::Union{Nothing, Vector{AlpineExpr}}
    power_part                      ::Union{Nothing, Vector{AlpineExpr}}
    bilinear_part                   ::Union{Nothing, Vector{AlpineExpr}}
    multilinear_part                ::Union{Nothing, Vector{AlpineExpr}}
    abs_part                        ::Union{Nothing, Vector{AlpineExpr}}
    trigonometric_part              ::Union{Nothing, Vector{AlpineExpr}}
    log_part                        ::Union{Nothing, Vector{AlpineExpr}}
    exp_part                        ::Union{Nothing, Vector{AlpineExpr}}
    other_part                      ::Union{Nothing, Vector{AlpineExpr}} # contains composite terms
    constant_part                   ::Union{Nothing, Vector{AlpineExpr}}
end 

NLFunction() = NLFunction(nothing, nothing, nothing, 
    nothing, nothing, nothing, nothing, 
    nothing, nothing, nothing, nothing)

mutable struct DAGVertex 
    vertex_type                     ::Union{Symbol} 
    depth                           ::Int
    vertex                          ::Union{Symbol, Expr, Float64, Int, Nothing} 
    children                        ::Vector{Union{Symbol, Expr, Float64, Int}}
    parents                         ::Vector{Union{Symbol, Expr, Float64, Int}}
    convexity                       ::Symbol 
    interval                        ::Interval{Float64}
end 

DAGVertex() = DAGVertex(:NaN, 0, nothing, 
    Vector{Union{Symbol, Expr, Float64, Int}}(), 
    Vector{Union{Symbol, Expr, Float64, Int}}(), 
    :undet, -Inf..Inf)

mutable struct DAG 
    max_depth                       ::Int 
    vertices                        ::Dict{Int, Vector{DAGVertex}}
end 

DAG() = DAG(0, Dict{Int, Vector{DAGVertex}}())

mutable struct QuadraticMatrixInfo
    Q                               ::SparseArrays.SparseMatrixCSC{Float64,Int64}
    index_to_variable_map           ::Dict{Int, VI}
end

mutable struct RedundantConstraints 
    linear_constraint_ids           ::Vector{Int}
    quadratic_constraint_ids        ::Vector{Int}
    soc_constraint_ids              ::Vector{Int}
    rsoc_constraint_ids             ::Vector{Int}
    nl_constraint_ids               ::Vector{Int}
end 

RedundantConstraints() = RedundantConstraints(Int[], Int[], Int[], Int[], Int[])

mutable struct AlpineProblem 
    # variable and constraint count
    num_variables                           ::Int 
    num_constraints                         ::Int
    num_linear_constraints                  ::Int 
    num_quadratic_constraints               ::Int  
    num_soc_constraints                     ::Int  
    num_rsoc_constraints                    ::Int  
    num_nl_constraints                      ::Int  
    num_binary_variables                    ::Int 
    num_integer_variables                   ::Int
    
    # constraint bound information
    constraint_bound_info                   ::Union{Nothing, Vector{Interval{Float64}}}
    objective_bound_info                    ::Union{Nothing, Interval{Float64}}

    # DAG 
    expression_graph                        ::Union{Nothing, DAG}
    dag_lookup                              ::Union{Nothing, Dict{Union{Expr, Symbol, Float64, Int}, Tuple{Int, Int}}}
    common_sub_expression_dict              ::Union{Nothing, Dict{Expr, Vector{Int}}}
    
    # JuMP models 
    mip                                     ::Union{Nothing, JuMP.Model}
    continuous_relaxation                   ::Union{Nothing, JuMP.Model} 
    obbt_model                              ::Union{Nothing, JuMP.Model}

    # Variable bounds information 
    variable_bound_original                 ::Union{Nothing, Vector{Interval{Float64}}}
    variable_bound_tightened                ::Union{Nothing, Vector{Interval{Float64}}}
    lifted_variable_bound                   ::Union{Nothing, Vector{Interval{Float64}}}

    # Nonlinear information 
    is_objective_linear                     ::Union{Nothing, Bool} 
    is_objective_quadratic                  ::Union{Nothing, Bool} 
    is_objective_nl                         ::Union{Nothing, Bool} 
    objective_expression                    ::Union{Nothing, Expr} 
    nl_constraint_expression                ::Union{Nothing, Vector{Expr}}
    nl_function                             ::Union{Nothing, Vector{NLFunction}}
    objective_nl_function                   ::Union{Nothing, NLFunction}
    nl_terms                                ::Union{Nothing, TermInfo}
    constraints_with_nl_terms               ::Union{Nothing, Vector{Int}}
    lifted_constraints                      ::Union{Nothing, Vector{JuMP.ConstraintRef}}
    lifted_var_info                         ::Union{Nothing, Dict{Int, Any}}

    # quadratic constraint information
    quadratic_nl_function                   ::Union{Nothing, Vector{NLFunction}}

    # quadratic matrix information 
    quadratic_matrix                        ::Union{Nothing, Vector{QuadraticMatrixInfo}}
    quadratic_matrix_nl                     ::Union{Nothing, Vector{Union{Nothing, QuadraticMatrixInfo}}}
    quadratic_matrix_objective              ::Union{Nothing, QuadraticMatrixInfo}

    # convexity information 
    objective_quadratic_matrix_convexity    ::Union{Nothing, Symbol}
    objective_function_convexity            ::Union{Nothing, Symbol}
    objective_convexity                     ::Union{Nothing, Symbol} 
    quadratic_function_convexity            ::Union{Nothing, Vector{Symbol}}
    quadratic_constraint_convexity          ::Union{Nothing, Vector{Symbol}}
    nl_quadratic_matrix_convexity           ::Union{Nothing, Vector{Symbol}}
    nl_function_convexity                   ::Union{Nothing, Vector{Symbol}}
    nl_constraint_convexity                 ::Union{Nothing, Vector{Symbol}}

    # redundant constraint information 
    redundant_constraint_ids                ::Union{Nothing, RedundantConstraints}

    # Incumbent information 
    incumbent                               ::Union{Nothing, Incumbent}

    # Algorithm status
    status                                  ::Union{Nothing, Status}

    # Algorithm progress 
    iteration                               ::Int

end 

AlpineProblem() = AlpineProblem(0, 0, 0, 0, 0, 0, 0, 0, 0,
    nothing, nothing, 
    nothing, nothing, nothing,
    nothing, nothing, nothing,
    nothing, nothing, nothing,
    nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing,
    nothing,
    nothing, nothing, nothing,
    nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing,
    nothing, 
    nothing, 
    nothing, 
    0
)
     
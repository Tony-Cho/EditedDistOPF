# src/parse_case.jl

using PowerModelsDistribution

function load_case(dss_path::String)
    eng = parse_file(dss_path)
    return eng
#     math = parse_file(
#         dss_path;
#         data_model = MATHEMATICAL,
#         kron_reduce = false
#     )
#     return math
end
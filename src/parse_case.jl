# src/parse_case.jl

using PowerModelsDistribution

function load_case(dss_path::String)
    eng = parse_file(dss_path)
    return eng
end
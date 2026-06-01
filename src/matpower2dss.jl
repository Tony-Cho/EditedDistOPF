using PowerModels
using Printf


# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

busname(i) = "bus$(Int(round(i)))"

function sorted_component_values(d::Dict)
    vals = collect(values(d))
    sort!(vals, by = x -> begin
        if haskey(x, "index")
            Int(round(x["index"]))
        elseif haskey(x, "source_id") && length(x["source_id"]) >= 2
            try
                Int(round(x["source_id"][2]))
            catch
                0
            end
        else
            0
        end
    end)
    return vals
end

function get_base_mva(data)
    if haskey(data, "baseMVA")
        return data["baseMVA"]
    elseif haskey(data, "base_mva")
        return data["base_mva"]
    else
        error("Cannot find baseMVA in PowerModels data.")
    end
end

function find_slack_bus(data)
    buses = data["bus"]
    for (_, bus) in buses
        if haskey(bus, "bus_type") && Int(round(bus["bus_type"])) == 3
            return Int(round(bus["bus_i"]))
        end
    end

    # fallback
    first_bus = first(values(buses))
    return Int(round(first_bus["bus_i"]))
end

function find_base_kv(data)
    buses = data["bus"]

    # Prefer slack bus base_kv
    slack = find_slack_bus(data)
    for (_, bus) in buses
        if Int(round(bus["bus_i"])) == slack
            return bus["base_kv"]
        end
    end

    # fallback
    return first(values(buses))["base_kv"]
end

# ------------------------------------------------------------
# Main converter
#
# input_units:
#   :raw_case33bw
#       Use this for modified/original case33bw where:
#       bus pd/qd are kW/kVAr
#       branch r/x are Ohm
#
#   :matpower_standard
#       Use this if your .m file has already been converted to standard MATPOWER:
#       bus pd/qd are MW/MVAr
#       branch r/x are p.u.
# ------------------------------------------------------------

function convert_pm_to_opendss(
    input_file::String,
    output_dir::String;
    input_units::Symbol = :raw_case33bw,
    frequency::Float64 = 50.0
)
    data = PowerModels.parse_file(input_file; validate = false)

    base_mva = get_base_mva(data)
    base_kv = find_base_kv(data)
    source_bus = find_slack_bus(data)

    zbase_ohm = base_kv^2 / base_mva

    mkpath(output_dir)

    master_path = joinpath(output_dir, "Master.dss")
    lines_path = joinpath(output_dir, "Lines.dss")
    loads_path = joinpath(output_dir, "Loads.dss")

    # --------------------------------------------------------
    # Master.dss
    # --------------------------------------------------------
    open(master_path, "w") do io
        println(io, "Clear")
        println(io)
        println(io, "! ===========================================================")
        println(io, "! OpenDSS model converted from MATPOWER using PowerModels.jl")
        println(io, "! Source file: $(input_file)")
        println(io, "! baseMVA = $(base_mva)")
        println(io, "! baseKV  = $(base_kv)")
        println(io, "! zbase_ohm = $(zbase_ohm)")
        println(io, "! ===========================================================")
        println(io)


        println(io, "! MATPOWER slack generator is represented by the OpenDSS circuit source.")
        println(io, @sprintf(
            "New Circuit.case33bw bus1=%s.1.2.3 basekv=%.6f pu=1.0 phases=3 angle=0 frequency=%.6f",
            busname(source_bus),
            base_kv,
            frequency
        ))


        println(io)
        println(io, @sprintf("Set VoltageBases=[%.6f]", base_kv))
        println(io, "CalcVoltageBases")
        println(io)

        println(io, "Redirect Lines.dss")
        println(io, "Redirect Loads.dss")
        println(io)

        println(io, "Set mode=snapshot")
        println(io, "Solve")
        println(io)

        println(io, "! Useful commands:")
        println(io, "! Show Voltages LN Nodes")
        println(io, "! Show Powers kVA Elements")
        println(io, "! Show Losses")
    end

    # --------------------------------------------------------
    # Lines.dss
    # --------------------------------------------------------
    open(lines_path, "w") do io
        println(io, "! ===========================================================")
        println(io, "! Lines")
        println(io, "! r1/x1/r0/x0 are represented as total ohms by using length=1")
        println(io, "! Since zero-sequence data are unavailable, r0/x0 = r1/x1")
        println(io, "! ===========================================================")
        println(io)

        branches = sorted_component_values(data["branch"])

        for br in branches
            idx = haskey(br, "index") ? Int(round(br["index"])) : 0

            f_bus = Int(round(br["f_bus"]))
            t_bus = Int(round(br["t_bus"]))
            status = haskey(br, "br_status") ? Int(round(br["br_status"])) : 1

            if input_units == :raw_case33bw
                r_ohm = br["br_r"]
                x_ohm = br["br_x"]
            elseif input_units == :matpower_standard
                r_ohm = br["br_r"] * zbase_ohm
                x_ohm = br["br_x"] * zbase_ohm
            else
                error("Unsupported input_units = $(input_units)")
            end

            lname = @sprintf("L%d_%d_%d", idx, f_bus, t_bus)

            if status == 1
                println(io, @sprintf(
                    "New Line.%s phases=3 bus1=%s.1.2.3 bus2=%s.1.2.3 r1=%.8f x1=%.8f r0=%.8f x0=%.8f c1=0 c0=0 length=1 units=km enabled=yes",
                    lname,
                    busname(f_bus),
                    busname(t_bus),
                    r_ohm,
                    x_ohm,
                    r_ohm,
                    x_ohm
                ))
            else
                println(io, @sprintf(
                    "New Line.%s phases=3 bus1=%s.1.2.3 bus2=%s.1.2.3 r1=%.8f x1=%.8f r0=%.8f x0=%.8f c1=0 c0=0 length=1 units=km switch=yes enabled=no",
                    lname,
                    busname(f_bus),
                    busname(t_bus),
                    r_ohm,
                    x_ohm,
                    r_ohm,
                    x_ohm
                ))
            end
        end
    end

    # --------------------------------------------------------
    # Loads.dss
    # PowerModels usually splits MATPOWER bus Pd/Qd into data["load"].
    # --------------------------------------------------------
    open(loads_path, "w") do io
        println(io, "! ===========================================================")
        println(io, "! Loads")
        println(io, "! Balanced three-phase loads")
        println(io, "! ===========================================================")
        println(io)

        if haskey(data, "load") && length(data["load"]) > 0
            loads = sorted_component_values(data["load"])

            for load in loads
                load_idx = haskey(load, "index") ? Int(round(load["index"])) : 0
                load_bus = Int(round(load["load_bus"]))

                if input_units == :raw_case33bw
                    kw = load["pd"]
                    kvar = load["qd"]
                elseif input_units == :matpower_standard
                    kw = load["pd"] * 1000.0
                    kvar = load["qd"] * 1000.0
                else
                    error("Unsupported input_units = $(input_units)")
                end

                if abs(kw) < 1e-9 && abs(kvar) < 1e-9
                    continue
                end

                # Find bus base kV
                kv = base_kv
                for (_, bus) in data["bus"]
                    if Int(round(bus["bus_i"])) == load_bus
                        kv = bus["base_kv"]
                        break
                    end
                end

                println(io, @sprintf(
                    "New Load.Load%d phases=3 bus1=%s.1.2.3 conn=wye kv=%.6f kw=%.6f kvar=%.6f model=1 status=variable",
                    load_idx,
                    busname(load_bus),
                    kv,
                    kw,
                    kvar
                ))
            end
        else
            # Fallback: if PowerModels does not split loads for some reason
            buses = sorted_component_values(data["bus"])

            for bus in buses
                b = Int(round(bus["bus_i"]))

                if !haskey(bus, "pd") || !haskey(bus, "qd")
                    continue
                end

                if input_units == :raw_case33bw
                    kw = bus["pd"]
                    kvar = bus["qd"]
                elseif input_units == :matpower_standard
                    kw = bus["pd"] * 1000.0
                    kvar = bus["qd"] * 1000.0
                else
                    error("Unsupported input_units = $(input_units)")
                end

                if abs(kw) < 1e-9 && abs(kvar) < 1e-9
                    continue
                end

                kv = bus["base_kv"]

                println(io, @sprintf(
                    "New Load.Load%d phases=3 bus1=%s.1.2.3 conn=wye kv=%.6f kw=%.6f kvar=%.6f model=1 status=variable",
                    b,
                    busname(b),
                    kv,
                    kw,
                    kvar
                ))
            end
        end
    end

    println("Conversion completed.")
    println("Input file: ", input_file)
    println("Output directory: ", output_dir)
    println("Generated:")
    println("  ", master_path)
    println("  ", lines_path)
    println("  ", loads_path)
end


# ------------------------------------------------------------
# CLI
# ------------------------------------------------------------

if abspath(PROGRAM_FILE) == @__FILE__

    if length(ARGS) < 1
        println("Usage:")
        println("  julia src/matpower2dss.jl data/case33bw.m data/opendss_case33 raw")
        println()
        println("Arguments:")
        println("  ARGS[1] : input MATPOWER .m file")
        println("  ARGS[2] : output OpenDSS folder, optional")
        println("  ARGS[3] : unit mode, raw or standard, optional")
        println()
        println("Examples:")
        println("  julia src/matpower2dss.jl data/case33bw.m")
        println("  julia src/matpower2dss.jl data/case33bw.m data/opendss_case33 raw")
        println("  julia src/matpower2dss.jl data/case33bw.m data/opendss_case33 standard")
        exit(1)
    end

    input_file = ARGS[1]

    output_dir = length(ARGS) >= 2 ? ARGS[2] : joinpath("data", "opendss_case33")

    unit_mode = :raw_case33bw

    if length(ARGS) >= 3
        mode = lowercase(ARGS[3])

        if mode == "raw"
            unit_mode = :raw_case33bw
        elseif mode == "standard"
            unit_mode = :matpower_standard
        else
            error("Third argument should be raw or standard.")
        end
    end

    convert_pm_to_opendss(
        input_file,
        output_dir;
        input_units = unit_mode
    )
end

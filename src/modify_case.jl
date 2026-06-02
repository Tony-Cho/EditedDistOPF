# src/modify_case.jl

function set_voltage_limits!(eng; vmin=0.95, vmax=1.05)
    for (bus_name, bus) in eng["bus"]
        terminals = get(bus, "terminals", Int[])

        if isempty(terminals)
            @warn "Bus $bus_name has no terminals. Skip."
            continue
        end

        n = length(terminals)

        bus["vm_lb"] = fill(vmin, n)
        bus["vm_ub"] = fill(vmax, n)

        if haskey(bus, "grounded")
            for g in bus["grounded"]
                idx = findfirst(==(g), terminals)
                if idx !== nothing
                    bus["vm_lb"][idx] = 0.0
                    bus["vm_ub"][idx] = 0.0
                end
            end
        end
    end

    return eng
end

function add_dg!(eng, bus_name; pg_max=0.5, qg_max=0.2)
    # 这里后面可以继续扩展
    return eng
end
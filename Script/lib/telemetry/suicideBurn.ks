runOncePath("0:/lib/telemetry/drag.ks").
runOncePath("0:/lib/telemetry/isp.ks").

global g0 to 9.80665.

function predictStopAltitude {
    parameter h.
    parameter u.
    parameter m.
    parameter maxSteps.
    parameter dt.

    local dt_half to dt / 2.
    local dt_sixth to dt / 6.

    local verticalRatio to abs(ship:verticalSpeed) / max(ship:velocity:surface:mag, 0.001).
    local totalThrust to sumThrust().
    local verticalThrust to totalThrust * verticalRatio.
    local effIsp to calcEffIsp().
    local radius to body:radius.
    local mu to body:mu.
    
    if effIsp <= 0 { set effIsp to 1. }

    local dm to -(totalThrust / (effIsp * g0)).

    for i in range(0, maxSteps) {
        set i to i.

        if h <= 0 { return 0. }

        local height to radius + h.
        if height <= 0 { return 0. }
        
        local g to mu / (height * height).

        local a_drag to 0.
        if u > 0 { set a_drag to (dragCoeff * u * u) / m. }

        // k1
        local k1_dh to -u.
        local k1_du to g - verticalThrust/m - a_drag.

        // k2
        local k2_u to u + k1_du * dt_half.
        local k2_m to m + dm * dt_half.
        local k2_dh to -k2_u.
        local k2_du to g - verticalThrust/k2_m - a_drag.

        set a_drag to 0.
        if k2_u > 0 { set a_drag to (dragCoeff * k2_u * k2_u) / m. }
        
        // k3
        local k3_u to u + k2_du * dt_half.
        local k3_m to m + dm * dt_half.
        local k3_dh to -k3_u.
        local k3_du to g - verticalThrust/k3_m - a_drag.

        set a_drag to 0.
        if k3_u > 0 { set a_drag to (dragCoeff * k3_u * k3_u) / m. }

        // k4
        local k4_u to u + k3_du * dt.
        local k4_m to m + dm * dt.
        local k4_dh to -k4_u.
        local k4_du to g - verticalThrust/k4_m - a_drag.

        set h to h + dt_sixth * (k1_dh + 2*k2_dh + 2*k3_dh + k4_dh).
        set u to u + dt_sixth * (k1_du + 2*k2_du + 2*k3_du + k4_du).
        set m to m + (dm * dt).

        if u <= 0 { return h. }
    }

    return h.
}
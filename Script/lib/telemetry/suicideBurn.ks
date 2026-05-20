runOncePath("0:/lib/telemetry/drag.ks").
runOncePath("0:/lib/telemetry/isp.ks").

global g0 to 9.80665.

function predictLanding {
    parameter pos.
    parameter vel.
    parameter m.
    parameter maxSteps.
    parameter dt.

    local dt_half to dt / 2.
    local dt_sixth to dt / 6.

    local totalThrust to sumThrust().
    local effIsp to calcEffIsp().
    local dm to -(totalThrust / (effIsp * g0)).
    local mu to body:mu.
    local tgo to 0.

    local function derivatives {
        parameter p.
        parameter v.
        parameter ms.

        local r to p:mag.
        local g_vec to p:normalized * (-mu / (r * r)).

        local thrust_acc to V(0,0,0).
        if v:mag > 0.1 {
            set thrust_acc to v:normalized * (-totalThrust / ms).
        }

        local spd to v:mag.
        local drag_acc to V(0,0,0).
        if spd > 0 {
            set drag_acc to v:normalized * (-(dragCoeff * spd * spd) / ms).
        }

        local a to g_vec + thrust_acc + drag_acc.
        return list(v, a).
    }

    for i in range(0, maxSteps) {

        set i to i.

        local alt_above_ground to pos:mag - body:radius - body:terrainheight(
            body:geopositionof(pos):lat,
            body:geopositionof(pos):lng
        ).
        if alt_above_ground <= 0 { break. }

        if vel:mag < 0.5 { break. }

        local d1 to derivatives(pos, vel, m).
        local k1_dp to d1[0].   local k1_dv to d1[1].

        local d2 to derivatives(pos + k1_dp*dt_half, vel + k1_dv*dt_half, m + dm*dt_half).
        local k2_dp to d2[0].   local k2_dv to d2[1].

        local d3 to derivatives(pos + k2_dp*dt_half, vel + k2_dv*dt_half, m + dm*dt_half).
        local k3_dp to d3[0].   local k3_dv to d3[1].

        local d4 to derivatives(pos + k3_dp*dt, vel + k3_dv*dt, m + dm*dt).
        local k4_dp to d4[0].   local k4_dv to d4[1].

        set pos to pos + (dt_sixth) * (k1_dp + 2*k2_dp + 2*k3_dp + k4_dp).
        set vel to vel + (dt_sixth) * (k1_dv + 2*k2_dv + 2*k3_dv + k4_dv).
        set m to m + dm * dt.
        set tgo to tgo + dt.
    }

    local finalAlt to pos:mag - body:radius.
    local bodyUp to pos:normalized.
    local horizVec to vxcl(bodyUp, pos - (ship:geoposition:position + body:position)).

    return lexicon(
        "stopAlt",    max(0, finalAlt - body:terrainheight(body:geopositionof(pos):lat, body:geopositionof(pos):lng)),
        "horizDist",  horizVec:mag,
        "tgo",        tgo
    ).
}
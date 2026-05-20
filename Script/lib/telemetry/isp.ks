function sumThrust {
    local thrustSum to 0.
    list engines in engineList.
    for eng in engineList {
        if eng:availablethrust > 0 {
            set thrustSum to thrustSum + eng:availablethrust.
        }
    }
    return thrustSum.
}

function sumIsp {
    local IspSum to 0.
    list engines in engineList.
    for eng in engineList {
        if eng:availablethrust > 0 and eng:isp > 0 {
            set IspSum to IspSum + eng:availablethrust / eng:isp.
        }
    }
    return IspSum.
}

global function calcEffIsp {
    local thrust to sumThrust().
    local ispSum to sumIsp().
    if thrust = 0 or ispSum = 0 { return 0. }
    return thrust / (body:mu / body:radius^2 * ispSum).
}
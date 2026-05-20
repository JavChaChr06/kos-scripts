set config:ipu to 2000.

runOncePath("0:/lib/telemetry/suicideBurn.ks").
runOncePath("0:/lib/telemetry/steering.ks").

clearscreen.

global predictedStopAltitude to 0.
global predictedStopHorizDist to 0.
global predictedTimeToStop    to 0.
global lastStopAltitude       to -1.
global dStopAltitude          to 0.
global lastTime               to time:seconds.
global boostETA               to 100000.
global landingPhase           to "INIT".

function printTelemetry {
    print "Phase:         " + landingPhase + "          "       at(0, 1).
    print "Predicted Alt: " + round(predictedStopAltitude, 1) + "m     " at(0, 2).
    print "Horiz Dist:    " + round(predictedStopHorizDist, 1) + "m     " at(0, 3).
    print "Burn ETA:      " + round(boostETA, 2)              + "s     " at(0, 4).
    print "TGO:           " + round(predictedTimeToStop, 2)   + "s     " at(0, 5).
    print "Srf Speed:     " + round(ship:velocity:surface:mag, 1) + "m/s  " at(0, 6).
    print "Radar Alt:     " + round(alt:radar, 1)             + "m     " at(0, 7).
    print "Vert Speed:    " + round(ship:verticalSpeed, 1)    + "m/s  " at(0, 8).
    print "Throttle:      " + round(throttle * 100, 1)        + "%     " at(0, 9).
}

function updatePrediction {
    updateDragCoeff().

    local result to predictLanding(
        ship:position - body:position,
        ship:velocity:surface,
        ship:mass,
        200,
        0.5
    ).
    set predictedStopAltitude to result["stopAlt"].
    set predictedStopHorizDist to result["horizDist"].
    set predictedTimeToStop    to result["tgo"].

    if lastStopAltitude < 0 { set lastStopAltitude to predictedStopAltitude. }
    set dStopAltitude to predictedStopAltitude - lastStopAltitude.

    local currentTime to time:seconds.
    local dTime to max(currentTime - lastTime, 0.02).

    set boostETA to 0.
    local roc to dStopAltitude / dTime.
    if roc <> 0 {
        set boostETA to predictedStopAltitude / abs(roc).
        if boostETA < 0.2 { set boostETA to 0. }
    }

    set lastStopAltitude to predictedStopAltitude.
    set lastTime to currentTime.
}

function zemZevGuidance {
    parameter targetGeo.
    parameter tgo.

    local safeTgo to max(tgo, 1.5).

    local r_current to ship:position.
    local v_current to ship:velocity:surface.
    local r_target  to targetGeo:position.

    local g_mag to body:mu / (body:radius + ship:altitude)^2.
    local g_vec to ship:up:vector * (-g_mag).

    local v_desired to ship:up:vector * (-2).

    local r_free to r_current
                 + v_current * safeTgo
                 + 0.5 * g_vec * safeTgo * safeTgo.

    local ZEM to r_target - r_free.
    local ZEV to v_desired - v_current.

    local a_cmd to (6.0 / (safeTgo * safeTgo)) * ZEM
                - (2.0 / safeTgo) * ZEV.

    local T_vec to ship:mass * (a_cmd - g_vec).
    local T_mag to T_vec:mag.

    local avail to max(ship:availableThrust, 0.01).
    local throttleCmd to min(1.0, max(0.0, T_mag / avail)).

    return lexicon(
        "steer",    T_vec:normalized,
        "throttle", throttleCmd,
        "a_cmd",    a_cmd
    ).
}

function runInit {
    lock throttle to 0.
    lock steering to lookdirup(-ship:velocity:surface:normalized, ship:facing:topvector).

    if ship:verticalSpeed < -50 { return "FALLING". }
    return "INIT".
}

function runFalling {
    updatePrediction().
    lock throttle to 0.

    if addons:tr:hasImpact {
        lock steering to getPrecisionSteering().
    } else {
        lock steering to lookdirup(-ship:velocity:surface:normalized, ship:facing:topvector).
    }

    if boostETA < 1.5 { return "IGNITION". }
    return "FALLING".
}

function runIgnition {
    gear on.
    ag2 on.
    return "BURN".
}

function runBurn {
    parameter targetGeo.
    updatePrediction().

    local tgo to predictedTimeToStop.

    if tgo < 0.5 or tgo > 300 {
        lock throttle to 1.
        lock steering to lookdirup(-ship:velocity:surface:normalized, ship:facing:topvector).
        return "BURN".
    }

    local guidance to zemZevGuidance(targetGeo, tgo).
    lock steering to lookdirup(guidance["steer"], ship:facing:topvector).
    lock throttle to guidance["throttle"].

    if alt:radar < 75 or ship:velocity:surface:mag < 10 {
        return "TERMINAL".
    }
    return "BURN".
}

function runTerminal {

    local local_g  to body:mu / (body:radius + ship:altitude)^2.
    local targetSpeed to -max(1, sqrt(2 * alt:radar)).
    local speedError  to targetSpeed - ship:verticalSpeed.

    local avail to ship:availableThrust.
    if avail < 0.01 {
        lock throttle to 0.
    } else {
        local hoverThrottle to (local_g * ship:mass) / avail.
        local thrustPerAccel to max(avail / ship:mass, 0.01).
        local gain to 1.0 / thrustPerAccel.
        lock throttle to min(1, max(0, hoverThrottle + speedError * gain)).
    }

    lock steering to getHoverSteering().

    if alt:radar < 1 or ship:status = "LANDED" or ship:status = "SPLASHED" {
        return "LANDED".
    }
    return "TERMINAL".
}

function landing {
    parameter targetGeo is ship:geoposition.

    sas off.
    set landingPhase to "INIT".

    until landingPhase = "LANDED" {
        if      landingPhase = "INIT"     { set landingPhase to runInit(targetGeo). }
        else if landingPhase = "FALLING"  { set landingPhase to runFalling(targetGeo). }
        else if landingPhase = "IGNITION" { set landingPhase to runIgnition(targetGeo). }
        else if landingPhase = "BURN"     { set landingPhase to runBurn(targetGeo). }
        else if landingPhase = "TERMINAL" { set landingPhase to runTerminal(targetGeo). }

        printTelemetry().
        wait 0.
    }

    lock throttle to 0.
    unlock steering.
    shutdown.
}

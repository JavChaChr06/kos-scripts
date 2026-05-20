set config:ipu to 2000.

runOncePath("0:/lib/telemetry/suicideBurn.ks").
runOncePath("0:/lib/telemetry/steering.ks").

clearscreen.

global predictedStopAltitude to 0.
global lastStopAltitude to -1.
global dStopAltitude to 0.
global lastTime to time:seconds.

function mainLoop {
    updateDragCoeff().

    if addons:tr:hasimpact {
        lock steering to getPrecisionSteering().
    } else {
        lock steering to srfRetrograde.
    }

    set predictedStopAltitude to predictStopAltitude(alt:radar, -verticalSpeed, ship:mass, 100, 0.5).

    if lastStopAltitude < 0 {
        set lastStopAltitude to predictedStopAltitude.
    }

    set dStopAltitude to predictedStopAltitude - lastStopAltitude.
    
    local currentTime to time:seconds.
    local dTime to currentTime - lastTime.
    if dTime <= 0 { set dTime to 0.02. }

    local rateOfChange to dStopAltitude / dTime.
    local boostETA to 0.
    if rateOfChange <> 0 {
        set boostETA to predictedStopAltitude / abs(rateOfChange).
        if boostETA < 0.2 { set boostETA to 0. }
    }

    set lastStopAltitude to predictedStopAltitude.
    set lastTime to currentTime.

    print "Predicted Alt: " + round(predictedStopAltitude, 1) + "m          " at(0, 2).
    print "Delta Alt:     " + round(dStopAltitude, 3) + "m          " at(0, 3).
    print "ETA:           " + round(boostETA, 1) + "s          " at(0, 4).
}

function landing {
    sas off.
    lock throttle to 0.
    lock steering to lookdirup(-ship:velocity:surface:normalized, ship:facing:topvector).

    wait until ship:verticalSpeed < -50.

    ag2 on.

    mainLoop().
    until predictedStopAltitude + dStopAltitude < 50 {
        mainLoop().
        wait 0.
    }

    gear on.
    lock throttle to 1.

    until ship:velocity:surface:mag < 10 {
        lock steering to getBurnSteering().
        wait 0.
    }

    until alt:radar < 1 {
        local local_g to body:mu / (body:radius + ship:altitude)^2.
    
        local targetSpeed to -max(1, sqrt(2*alt:radar)).
        local speedError to targetSpeed - ship:verticalSpeed.

        local thrust to ship:availableThrust.
        if thrust < 0.01 { set hoverThrottle to 0. } else { set hoverThrottle to (local_g * ship:mass) / thrust. }
        lock throttle to hoverThrottle + (speedError * 0.1).

        lock steering to getHoverSteering().
        wait 0.
    }

    lock throttle to 0.
    unlock steering.

    shutdown.
}
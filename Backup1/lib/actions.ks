runOncePath("0:/lib/helper.ks").

function launch {
    sas off.
    lock THROTTLE to 1.
    lock STEERING to heading(90, 90).

    PRINT "Counting down:".
    FROM {local countdown is 3.} UNTIL countdown = 0 STEP {SET countdown to countdown - 1.} DO {
        PRINT "..." + countdown.
        WAIT 1.
    }

    print "Ignition.".
    stage.
    wait 0.5.
    print "Liftoff.".
    stage.
}

function apsToHeight {
    parameter apsHeight.

    wait until ship:velocity:surface:mag >= 150.
    print "Starting gravity turn".

    lock steering to heading(90, 85).

    wait until vAng(ship:facing:vector, heading(90, 85):vector) <= 0.3.
    print "In position.".

    wait until vAng(ship:srfPrograde:vector, ship:facing:vector) <= 0.3.
    print "Following prograde".
    lock steering to Prograde.

    until ship:apoapsis >= apsHeight {
        if shouldAutostage() {
            print "Flameout detected - staging.".
            stage.
            wait 0.5.
        }
        wait 0.5.
    }

    lock THROTTLE to 0.
    set ship:control:pilotmainthrottle to 0.
}

function circOrbit {
    parameter apsAlt.

    local mu is body:mu.
    local br is body:radius.

    local vom is velocity:orbit:mag.
    local dist is br + altitude.
    local ra is br + apoapsis.
    local v1 is sqrt( vom^2 + 2*mu*(1/ra - 1/dist) ).

    local sma1 is (periapsis + 2*br + apoapsis)/2.

    local r2 is br + apoapsis.
    local sma2 is ((apsAlt) + 2*br + apoapsis)/2.
    local v2 is sqrt( vom^2 + (mu * (2/r2 - 2/dist + 1/sma1 - 1/sma2 ) ) ).

    local deltav is v2 - v1.
    local circNode is node(time:seconds + eta:apoapsis, 0, 0, deltav).
    add circNode.
}
global dragCoeff to 0.
global lastVes to V(0,0,0).
global vesTime to time:seconds.
global myAcc to V(0,0,0).

set dragCoeff to dragCoeff.

global function updateDragCoeff {

    local g to body:mu / (altitude + body:radius)^2.

    local dt to time:seconds - vesTime.
    if dt > 0 {
        set myAcc to (ship:velocity:surface - lastVes) / dt.
        set vesTime to time:seconds.
        set lastVes to ship:velocity:surface.
    }

    local thrustVec to ship:facing:forevector * ship:maxthrust * throttle.
    local gravVec to ship:up:vector * -1 * g * ship:mass.
    local realForceOnShip to myAcc * ship:mass.

    local airResVec to V(0,0,0).
    if (ship:status = "LANDED" or ship:status = "SPLASHED" or ship:status = "PRELAUNCH") {
        set airResVec to V(0,0,0).
        set dragCoeff to 0.
        return.
    } else {
        set airResVec to realForceOnShip - thrustVec - gravVec.
    }

    local spd to ship:velocity:surface:mag.
    if spd > 0 {
        set dragCoeff to airResVec:mag / (spd * spd).
    }
}.
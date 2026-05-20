function getPrecisionSteering {
    if not addons:tr:hasTarget or not addons:tr:hasImpact { 
        return lookdirup(ship:srfRetrograde:vector, ship:facing:topvector). 
    }

    local targetGeo to addons:tr:gettarget. 
    local impactGeo to addons:tr:impactpos.

    local targetPos to targetGeo:position.
    local impactPos to impactGeo:position.

    local errorVec to targetPos - impactPos.
    
    local horizError to vxcl(ship:up:vector, errorVec).
    local distanceError to horizError:mag.

    if distanceError < 10 {
        return lookdirup(ship:srfRetrograde:vector, ship:facing:topvector).
    }

    local maxAoA to 20.
    local tiltAngle to min(maxAoA, distanceError / 10).

    local retroVec to ship:srfRetrograde:vector.
    
    local rotAxis to vCrs(horizError, retroVec).
    
    local steerVec to angleAxis(tiltAngle, rotAxis) * retroVec.

    return lookdirup(steerVec, ship:facing:topvector).
}

function getBurnSteering {
    local maxAoA to 15.
    local aggression to 1.
    local stopSteeringDist to 5.

    if not addons:tr:hasTarget { return ship:srfRetrograde. }

    local targetPos to addons:tr:gettarget():position.
    local horizToTarget to vxcl(ship:up:vector, targetPos).
    local distance to horizToTarget:mag.

    if distance < stopSteeringDist {
        return lookdirup(ship:srfRetrograde:vector, ship:facing:topvector).
    }

    local timeToLand to predictedStopAltitude / max(0.1, abs(ship:verticalSpeed)).
    if timeToLand < 1 { set timeToLand to 1. }

    local neededHorizVel to horizToTarget / timeToLand.
    local currentHorizVel to vxcl(ship:up:vector, ship:velocity:surface).

    local velError to neededHorizVel - currentHorizVel.

    local retroVec to ship:srfRetrograde:vector.
    local steerVec to retroVec.

    if velError:mag > 0.1 {
        local requestedTilt to velError:mag * aggression.
        local actualTilt to min(maxAoA, requestedTilt).

        local rotAxis to vCrs(retroVec, velError).
        
        set steerVec to angleAxis(actualTilt, rotAxis) * retroVec.
    }

    return lookdirup(steerVec, ship:facing:topvector).
}

function getHoverSteering {
    local maxTilt to 5.
    local maxSpeed to 2.
    local aggression to 2.0.

    local desiredVel to v(0,0,0).

    if addons:tr:hasTarget {
        local targetPos to addons:tr:gettarget():position.
        local horizToTarget to vxcl(ship:up:vector, targetPos).
        
        if horizToTarget:mag > 1 {
            set desiredVel to horizToTarget * 0.2.
            if desiredVel:mag > maxSpeed {
                set desiredVel to desiredVel:normalized * maxSpeed.
            }
        }
    }

    local currentHorizVel to vxcl(ship:up:vector, ship:velocity:surface).
    
    local velError to desiredVel - currentHorizVel.
    
    local steerVec to ship:up:vector.

    if velError:mag > 0.05 {
        local actualTilt to min(maxTilt, velError:mag * aggression).
        
        local rotAxis to vCrs(ship:up:vector, velError).
        set steerVec to angleAxis(actualTilt, rotAxis) * ship:up:vector.
    }

    return lookdirup(steerVec, ship:facing:topvector).
}
runOncePath("0:/lib/helper.ks").
runOncePath("0:/lib/navigation.ks").

global logs to "0:/log/landing.log".

if exists(logs) {
    deletepath(logs).
}

log "=== Landing Log Started at T+" + round(time:seconds) + " ===" to logs.

global function logLine {
    parameter msg.
    //print msg.
    log msg to logs.
}

global function vecToStr {
    parameter vec.
    return "(" + round(vec:x,3) + "," + round(vec:y,3) + "," + round(vec:z,3) + ")".
}

global function boostback {
    sas off. rcs on.
    addons:tr:settarget(landingLocation).
    local steerTarget to ship:facing:vector.
    lock steering to lookDirUp(steerTarget, ship:facing:topvector).
    local burnStartTime to time:seconds.
    local minDistSeen to 999999.
    local lastLogTime to 0.

    logLine("--- Boostback Start ---").
    logLine("  Landing target: " + round(landingLocation:lat,4) + ", " + round(landingLocation:lng,4)).
    local initImpact to addons:tr:impactpos.
    logLine("  Initial impact: " + round(initImpact:lat,4) + ", " + round(initImpact:lng,4)).
    logLine("  Initial dist: " + round(surfaceDist(landingLocation, initImpact),1) + "m").

    until false {
        local impactPos   to addons:tr:impactpos.
        local currentDist to surfaceDist(landingLocation, impactPos).

        if currentDist < minDistSeen { set minDistSeen to currentDist. }

        if currentDist <= 200 {
            logLine("BREAK: dist <= 200m (dist=" + round(currentDist,1) + "m)").
            break.
        }

        if minDistSeen < 3000 and currentDist > minDistSeen + 50 {
            logLine("BREAK: Overshoot detected (dist=" + round(currentDist,1) + "m, minSeen=" + round(minDistSeen,1) + "m)").
            break.
        }

        local elapsed to time:seconds - burnStartTime.
        if elapsed > 10 and currentDist > minDistSeen + 5000 and currentDist > 1000 {
            logLine("BREAK: diverging (dist=" + round(currentDist,1) + "m, minSeen=" + round(minDistSeen,1) + "m, elapsed=" + round(elapsed,2) + "s)").
            break.
        }


        local errorBear   to bearingTo(impactPos, landingLocation).
        local baseBear    to bearingTo(ship:geoposition, landingLocation).
        
        local errorVecDir to heading(errorBear, 0):vector.
        local baseDirVec  to heading(baseBear, 0):vector.

        local thrustWeight to max(0, min(0.90, currentDist / 10000)).
        if currentDist < 200 { set thrustWeight to 0. }

        local rawDir to safeNorm(baseDirVec * (1 - thrustWeight) + errorVecDir * thrustWeight).
        set steerTarget to safeNorm(horiz(rawDir) - up:vector * 0.02).

        local angError to vAng(ship:facing:vector, steerTarget).
        local throttleValue to 0.
        
        if angError < 5 {
            set throttleValue to min(1, currentDist / 2000).
        }
        lock throttle to throttleValue.

        if (time:seconds - lastLogTime) >= 0.5 {
            local velSurf to ship:velocity:surface.
            logLine("  t+" + round(elapsed,1) + "s dist=" + round(currentDist,1) + "m minSeen=" + round(minDistSeen,1) + "m angErr=" + round(angError,1) + "deg thr=" + round(throttleValue,2) + " hdg=" + round(ship:heading,1) + " impact=(" + round(impactPos:lat,4) + "," + round(impactPos:lng,4) + ")").
            logLine("    vectors baseDir=" + vecToStr(baseDirVec) + " errDir=" + vecToStr(errorVecDir) + " steer=" + vecToStr(steerTarget) + " velSurf=" + vecToStr(velSurf) + " face=" + vecToStr(ship:facing:vector)).
            set lastLogTime to time:seconds.
        }

        wait 0.
    }

    unlock throttle.
    unlock steering.
    local finalErr to round(surfaceDist(landingLocation, addons:tr:impactpos), 1).
    logLine("--- Boostback Done. Final error: " + finalErr + "m ---").
    print "Boostback done. Final error: " + finalErr + "m".
}

global function glide {
    print "Starting Glide and Landing phase...".
    logLine("--- Glide Start ---").
    sas off. rcs on. brakes on.

    local throt to 0.
    lock throttle to throt.
    
    local smoothSteer to ship:srfretrograde:forevector.
    lock steering to lookDirUp(smoothSteer, ship:facing:topvector).

    local prevErrorVec to V(0,0,0).
    local prevBurnCorrVec to V(0,0,0).
    local prevTime to time:seconds.
    
    local radarOffset to 15. 
    local isBurning to false.
    local lastLogTime to 0.

    until ship:status = "LANDED" or ship:status = "SPLASHED" {
        local trueAlt to max(0.1, alt:radar - radarOffset).
        local vel to ship:velocity:surface:mag.
        local vertV to -ship:verticalspeed.
        local nowTime to time:seconds.
        local dt to max(0.02, nowTime - prevTime).
        local idealThrottle to 0.
        local estStopDist to 0.
        local burnLead to 1.15.
        local hoverThrottle to 0.
        local targetDown to 0.

        local maxAcc to ship:availablethrust / ship:mass.
        if maxAcc > 0 {
            local g to body:mu / body:radius^2.
            local twr to maxAcc / g.
            
            local stopDist to max(0.1, trueAlt - 5). 
            local reqAcc to (vel^2) / (2 * stopDist).
            set idealThrottle to (reqAcc + g) / maxAcc.

            local decelAcc to max(0.1, maxAcc - g * 0.9).
            set estStopDist to (vel^2) / (2 * decelAcc).
            if twr < 2.0 { set burnLead to 1.35. }
            if twr < 1.5 { set burnLead to 1.55. }

            if trueAlt < 40 {
                local targetSpeed to max(2, trueAlt * 0.25). 
                local speedError to vel - targetSpeed.
                
                set hoverThrottle to g / maxAcc.
                set idealThrottle to hoverThrottle + (speedError * 0.15).
            }

            if (idealThrottle > 0.90 and trueAlt < 9000) or (estStopDist > trueAlt * burnLead and vertV > 20) or (trueAlt < 40 and isBurning) {
                set isBurning to true.
            }

            if isBurning {
                // High-TWR boosters need vertical-speed control to avoid weak early burn and rebound.
                set hoverThrottle to g / maxAcc.
                set targetDown to max(3, min(90, trueAlt * 0.20)).
                if trueAlt < 3000 { set targetDown to max(8, min(55, trueAlt * 0.14)). }
                if trueAlt < 800  { set targetDown to max(4, min(22, trueAlt * 0.08)). }
                if trueAlt < 120  { set targetDown to max(0.8, trueAlt * 0.10). }
                if trueAlt < 40   { set targetDown to max(0.4, trueAlt * 0.07). }

                local downErr to vertV - targetDown.
                local pGain to 0.025.
                if twr > 2.5 { set pGain to 0.035. }
                if twr > 3.5 { set pGain to 0.045. }

                set idealThrottle to hoverThrottle + downErr * pGain.

                if trueAlt < 60 and ship:verticalspeed > 0.5 {
                    set idealThrottle to min(idealThrottle, hoverThrottle * 0.75).
                }
            }

            if isBurning { set throt to max(0.00, min(1.0, idealThrottle)). } else { set throt to 0. }
            
        } else {
            set throt to 0.
        }

        if trueAlt < 800 { gear on. }
        if trueAlt < 2 and vel < 2 { set throt to 0. break. }

        local retro to ship:srfretrograde:forevector.
        local rawSteer to retro.
        local errorMag to 0.
        local corrVecNow to V(0,0,0).
        local burnTilt to 0.
        local corrRateAlong to 0.

        if addons:tr:hasimpact {
            local impactPos to addons:tr:impactpos:position.
            local targetPos to addons:tr:gettarget:position.
            
            local corrVec to horiz(targetPos - impactPos).
            set corrVecNow to corrVec.
            set errorMag to corrVec:mag.

            if not isBurning {
                local activeGain to 0.10.
                local gainDamping to 0.00.
                local maxAoA to 40.
                local deadzone to 10.

                if vel > 1100 and trueAlt < 45000 { set activeGain to 0.08. set gainDamping to 0.02. set maxAoA to 8. set deadzone to 60. }
                if vel > 900 and trueAlt < 30000  { set activeGain to 0.09. set gainDamping to 0.03. set maxAoA to 12. set deadzone to 40. }
                if trueAlt < 15000 { set activeGain to 0.20. set gainDamping to 0.04. set maxAoA to 30. }
                if trueAlt < 5000  { set activeGain to 0.14. set gainDamping to 0.08. set maxAoA to 10. set deadzone to 5. }
                if trueAlt < 2000  { set activeGain to 0.10. set gainDamping to 0.12. set maxAoA to 5. set deadzone to 0.5. }

                local errorRateVec to (corrVec - prevErrorVec) / dt.
                local cmdVec to corrVec * activeGain + errorRateVec * gainDamping.
                local cmdDir to safeNorm(cmdVec).
                
                if errorMag > deadzone and cmdDir:mag > 0 { set rawSteer to safeNorm(retro - cmdDir * min(0.35, errorMag / 400)). }

                local ang to vang(retro, rawSteer).
                if ang > maxAoA { set rawSteer to safeNorm(retro * (1 - (maxAoA/ang)) + rawSteer * (maxAoA/ang)). }

                set prevErrorVec to corrVec.
                
            } else {
                if trueAlt > 50 and errorMag > 2 and vertV > 5 {
                    local corrRateVec to (corrVec - prevBurnCorrVec) / dt.
                    if errorMag > 0.5 {
                        set corrRateAlong to vdot(corrRateVec, safeNorm(corrVec)).
                    }

                    local tiltMax to 0.18.
                    if trueAlt > 3000 { set tiltMax to 0.22. }
                    if trueAlt < 1200 { set tiltMax to 0.12. }
                    if trueAlt < 400  { set tiltMax to 0.08. }

                    local tiltForce to min(tiltMax, errorMag / 500).
                    if corrRateAlong > 10  { set tiltForce to min(tiltMax, tiltForce * 1.35). }
                    if corrRateAlong < -15 { set tiltForce to max(0, tiltForce * 0.55). }
                    if errorMag < 60 { set tiltForce to 0. }
                    if horiz(ship:velocity:surface):mag < 6 and trueAlt < 1500 { set tiltForce to min(tiltForce, 0.05). }

                    local burnCmdVec to corrVec - corrRateVec * 0.18.
                    local burnCmdDir to safeNorm(burnCmdVec).

                    if burnCmdDir:mag > 0 and tiltForce > 0 {
                        set rawSteer to safeNorm(retro + burnCmdDir * tiltForce).
                        set burnTilt to tiltForce.
                    }
                }

                set prevBurnCorrVec to corrVec.
            }
        }
        
        local horizV to horiz(ship:velocity:surface):mag.
        if trueAlt < 50 or (isBurning and horizV < 1.5) {
            set rawSteer to up:vector.
        }

        set smoothSteer to safeNorm(smoothSteer * 0.82 + rawSteer * 0.18).
        set prevTime to nowTime.

        if (time:seconds - lastLogTime) >= 2.0 {
            local velSurf to ship:velocity:surface.
            local upVec to up:vector.
            local attPitch to 90 - vang(ship:facing:vector, upVec).
            local faceUpErr to vang(ship:facing:vector, upVec).
            local aoaCmd to vang(retro, rawSteer).

            logLine("  glide alt=" + round(trueAlt,1) + "m vel=" + round(vel,1) + "m/s vv=" + round(ship:verticalspeed,1) + "m/s hv=" + round(horizV,1) + "m/s thr=" + round(throt,2) + " ideal=" + round(idealThrottle,2) + " burning=" + isBurning + " err=" + round(errorMag,1) + "m").
            logLine("    burn estStop=" + round(estStopDist,1) + "m lead=" + round(burnLead,2) + " targetDown=" + round(targetDown,1) + "m/s hoverThr=" + round(hoverThrottle,2)).
            logLine("    corr burnTilt=" + round(burnTilt,3) + " corrRate=" + round(corrRateAlong,1) + "m/s").
            logLine("    attitude hdg=" + round(ship:heading,1) + " pitch=" + round(attPitch,1) + " faceUpErr=" + round(faceUpErr,1) + "deg aoaCmd=" + round(aoaCmd,1) + "deg").
            logLine("    vectors retro=" + vecToStr(retro) + " rawSteer=" + vecToStr(rawSteer) + " smooth=" + vecToStr(smoothSteer) + " velSurf=" + vecToStr(velSurf) + " corrVec=" + vecToStr(corrVecNow)).
            set lastLogTime to time:seconds.
        }

        wait 0.
    }

    unlock steering.
    unlock throttle.
    brakes off.
    rcs off.
    sas on.
    logLine("--- Touchdown ---").
    print "Touchdown!".
}
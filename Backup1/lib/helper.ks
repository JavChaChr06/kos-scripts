function shouldAutostage {
    
    list ENGINES in engineList.
    for eng in engineList {
        if eng:flameout {
            return true.
        }
    }

    return false.
}

function execNextNode {
    set nd to nextnode.
    
    print "Node in: " + round(nd:eta) + ", DeltaV: " + round(nd:deltav:mag).

    set max_acc to ship:maxthrust/ship:mass.

    set burn_duration to nd:deltav:mag/max_acc.
    print "Crude Estimated burn duration: " + round(burn_duration) + "s".
    
    wait until nd:eta <= (burn_duration/2 + 60).

    set np to nd:deltav.
    lock steering to np.

    wait until vang(np, ship:facing:vector) < 0.25.

    wait until nd:eta <= (burn_duration/2).
    
    set tset to 0.
    lock throttle to tset.

    set done to False.
    set dv0 to nd:deltav.
    until done {
        set max_acc to ship:maxthrust/ship:mass.

        set tset to min(nd:deltav:mag/max_acc, 1).

        if vdot(dv0, nd:deltav) < 0
        {
            print "End burn, remain dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
            lock throttle to 0.
            break.
        }

        if nd:deltav:mag < 0.1
        {
            print "Finalizing burn, remain dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
            wait until vdot(dv0, nd:deltav) < 0.5.

            lock throttle to 0.
            print "End burn, remain dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
            set done to True.
        }
    }
    unlock steering.    
    unlock throttle.
    wait 1.

    remove nd.

    set ship:control:pilotmainthrottle to 0.
}

global function surfaceDist {
    parameter a, b.
    local lat1 to a:lat.
    local lat2 to b:lat.
    local dLng to b:lng - a:lng.
    local cosAng to max(-1, min(1, sin(lat1)*sin(lat2) + cos(lat1)*cos(lat2)*cos(dLng))).
    return body:radius * arccos(cosAng) * constant:degtorad.
}

global function bearingTo {
    parameter from, to.
    local dLng to to:lng - from:lng.
    local y to sin(dLng) * cos(to:lat).
    local x to cos(from:lat)*sin(to:lat) - sin(from:lat)*cos(to:lat)*cos(dLng).
    return arctan2(y, x).
}

global function horiz {
    parameter vec.
    return vec - (vec * up:vector) * up:vector.
}

global function safeNorm {
    parameter vec.
    if vec:mag < 0.0001 return V(0,0,0).
    return vec:normalized.
}
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
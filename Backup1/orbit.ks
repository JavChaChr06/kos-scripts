runOncePath("0:/lib/helper.ks").
runOncePath("0:/lib/actions.ks").

clearscreen.

local orbitAltitude is 200000.

launch().

apsToHeight(orbitAltitude).
wait 0.1.

circOrbit(ship:apoapsis).

execNextNode().
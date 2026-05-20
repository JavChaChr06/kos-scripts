runOncePath("0:/lib/helper.ks").
runOncePath("0:/lib/landing_actions.ks"). 

//set landingLocation to latlng(0.0132933482527733, -74.5616139902344). //TSC 39A
//set landingLocation to latlng(0.129696026444435, -74.5649337768555). //TSC 39B
set landingLocation to latlng(-0.2057164311409, -74.4730606079102). //Landing Zone 1
//set landingLocation to latlng(-0.275359630584717, -74.6072082519531). //TLC Vertical Test Pad
//set landingLocation to latlng(-0.233044892549515, -74.5026779174805). //TLC 40
//set landingLocation to latlng(-0.168433308601379, -74.5312805175781). //TLC 41


clearScreen.
print "Booster CPU ready.".

wait 1.
wait until stage:number = 0.
print "Taking control from booster.".

lock throttle to 0.
wait 1.

AG1 ON.

addons:tr:settarget(landingLocation).

boostback().
glide().
//hoverslam().

set ship:control:pilotmainthrottle to 0.

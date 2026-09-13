// Dragonfly Control Software

SET CONFIG:IPU TO 2000.
PARAMETER targetAlt.
GLOBAL flightMode IS "LIFTOFF".

// PID Controllers
GLOBAL alt_pid IS PIDLOOP(0.05, 0.005, 0.1, 0, 1).
GLOBAL vs_pid IS PIDLOOP (0.1, 0.01, 0.05, 0, 1).
GLOBAL speed_pid IS PIDLOOP (0.5, 0.1, 0.25, 0, 45).

PRINT "Dragonfly Control Software Initiated.".
WAIT 3.

// Waypoint Search Function
LOCAL wpList IS LIST().
FOR wp IN ALLWAYPOINTS() {
    IF wp:BODY = SHIP:BODY {
        wpList:ADD(wp).
    }
}

IF wpList:LENGTH = 0 {
    PRINT "Error: Navigation is not operable.".
    PRINT "No waypoints found on this planet.".
    PRINT "Please add a waypoint in this planet.".
    WAIT 3.
    SHUTDOWN. // Ends script if there are no waypoints.
}

CLEARSCREEN.
PRINT "===================================".
PRINT "        AVAILABLE WAYPOINTS        ".
PRINT "===================================".
LOCAL idx IS 0.
FOR wp IN wpList {
    PRINT "[" + idx + "] " + wp:NAME.
    SET idx TO idx + 1.
}
PRINT "===================================".

LOCAL validChoise IS FALSE.
LOCAL currentWP IS 0.

UNTIL validChoise {
    PRINT "Enter the waypoint number to target: ".
    LOCAL userInput IS TERMINAL:INPUT:GETCHAR().
    LOCAL userNum IS userInput:TONUMBER(-1). //Returns -1 if input is invalid.
    
    IF userNum >=0 AND userNum < wpList:LENGTH {
        SET currentWP TO wpList[userNum].
        SET validChoise TO TRUE.
    } ELSE {
        PRINT "Invalid choise. Please select a number from the list above.".
    }
}

CLEARSCREEN.
PRINT "Target Locked: " + currentWP:NAME.
PRINT "Activating Autopilot...".
WAIT 5.

// Main Control Loop
UNTIL flightMode = "ARRIVED" {
    IF flightMode = "LIFTOFF" {
        Liftoff().
        SET flightMode TO "CRUISE".
    }
    ELSE IF flightMode = "CRUISE" {
        Cruise().
        SET flightMode TO "APPROACH".
    }
    ELSE IF flightMode = "APPROACH" {
        Approach().
        SET flightMode TO "LAND".
    }
    ELSE IF flightMode = "LAND" {
        Land().
        SET flightMode TO "ARRIVED".
    }
    WAIT 0.1.
}

executeScienceSequence().

FUNCTION Liftoff {
    PRINT "Flight Mode: Liftoff " AT (0, 8).
    LOCK STEERING TO HEADING(currentWP:GEOPOSITION:HEADING, 0).
    LOCK THROTTLE TO 0.33.

    WAIT UNTIL ALT:RADAR >= 100.
    PRINT "Transitioning to Cruise Mode.      " AT (0, 10).
}

FUNCTION Cruise {
    PRINT "Flight Mode: Cruise  " AT (0, 8).
    LOCAL targetHeading IS currentWP:GEOPOSITION:HEADING.

    SET alt_pid:SETPOINT TO targetAlt. // Target altitude above sea level.
    SET speed_pid:SETPOINT TO 50. // Target forward speed in m/s.

    LOCAL current_throttle IS 1.0.
    LOCAL current_pitch IS 0.

    LOCK STEERING TO HEADING(targetHeading, current_Pitch).
    LOCK THROTTLE TO current_throttle.

    // Approach Mode Activation Variables
    LOCAL gravity IS BODY:MU / BODY:RADIUS^2.
    LOCAL maxPitch IS 45.
    LOCAL craftBrake IS gravity * TAN(maxPitch).
    LOCAL aeroBrake IS 3.0. // Adjust this number based on current planet's atmospheric density.
    LOCAL totalBrake IS craftBrake + aeroBrake.
    LOCAL targetSpeed IS speed_pid:SETPOINT.
    LOCAL brakeDist IS (targetSpeed^2) / (2 * totalBrake).
    LOCAL approachDist IS brakeDist * 1.2.
    LOCAL triggerDist IS SQRT(targetAlt^2 + approachDist^2).

    PRINT "Target Altitude: " + targetAlt + "m" AT (0, 5).

    LOCAL currentPlanet IS SHIP:BODY.
    LOCAL currentPosition IS SHIP:GEOPOSITION.

    UNTIL currentWP:GEOPOSITION:DISTANCE <= triggerDist {       
        
        SET targetHeading TO currentWP:GEOPOSITION:HEADING.
        SET current_pitch TO -1 * speed_pid:UPDATE(TIME:SECONDS, SHIP:VELOCITY:SURFACE:MAG).
        SET current_throttle TO alt_pid:UPDATE(TIME:SECONDS, ALTITUDE).
            
        SET terrainElevation TO ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
        SET terrainSlope TO ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
        SET terrainBiome TO ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).
        
        printFlightData(currentWP, currentPlanet, currentPosition).

        WAIT 0.1.
    }
    PRINT "Transitioning to Approach Mode.    " AT (0, 10).
}

FUNCTION Approach {
    PRINT "Flight Mode: Approach" AT (0, 8).
    LOCAL targetHeading IS currentWP:GEOPOSITION:HEADING.
    SET alt_pid:SETPOINT TO targetAlt.

    LOCAL current_throttle IS 1.0.
    LOCAL current_pitch IS 0.
    LOCAL groundDistance IS VXCL(UP:VECTOR, currentWP:GEOPOSITION:POSITION):MAG.
    
    LOCAL minDistance IS groundDistance.

    LOCK STEERING TO HEADING(targetHeading, current_pitch).
    LOCK THROTTLE TO current_throttle.

    LOCAL currentPlanet IS SHIP:BODY.
    LOCAL currentposition IS SHIP:GEOPOSITION.

    UNTIL SHIP:VELOCITY:SURFACE:MAG < 5 {
        SET groundDistance TO VXCL(UP:VECTOR, currentWP:GEOPOSITION:POSITION):MAG.
    
        IF groundDistance < minDistance {
            SET minDistance TO groundDistance.
        }
    
        IF minDistance < 2 {
            SET minDistance TO 0.
        }

        LOCAL dynamicSpeed IS SQRT(minDistance) * 1.5.
    
        SET speed_pid:SETPOINT TO dynamicSpeed.
        SET current_pitch TO -1 * speed_pid:UPDATE(TIME:SECONDS, SHIP:VELOCITY:SURFACE:MAG).
        SET current_throttle TO alt_pid:UPDATE(TIME:SECONDS, ALTITUDE).

        SET terrainElevation TO ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
        SET terrainSlope TO ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
        SET terrainBiome TO ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).

        printFlightData(currentWP, currentPlanet, currentPosition).

        WAIT 0.1.
    }
    PRINT "Transitioning to Landing Mode.     " AT (0, 10).
}

FUNCTION Land {
    PRINT "Flight Mode: Landing  " AT (0, 8).
    
    LOCAL targetHeading IS currentWP:GEOPOSITION:HEADING.
    LOCAL current_throttle IS THROTTLE.
    LOCAL levelPitch IS VXCL(UP:VECTOR, SHIP:FACING:FOREVECTOR).
    LOCAL idleThrottle IS 0.15.

    LOCK STEERING TO LOOKDIRUP(levelPitch, UP:VECTOR).
    LOCK THROTTLE TO current_throttle.

    WAIT 0.1.

    UNTIL SHIP:STATUS = "LANDED" {
        LOCAL dynamicVS IS -1 * SQRT(ALT:RADAR) * 0.5.

        SET dynamicVS TO MIN(-1.0, dynamicVS).
        SET vs_pid:SETPOINT TO dynamicVS.

        LOCAL pidOutput IS vs_pid:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).

        SET current_throttle TO MAX(idleThrottle, pidOutput).

        WAIT 0.1.
    }
    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    PRINT "Touchdown Confirmed. Safely Landed." AT (0, 10).
}

// Additional Functions

FUNCTION executeScienceSequence {
    PRINT "Initiating scientific analysis...     " AT (0, 12).
    SET current_throttle TO 0.

    PRINT "Deploying sampling drill...           " AT (0, 12).
    TOGGLE AG1.
    WAIT 15.
    
    PRINT "Analyzing gravitational activity...   " AT (0, 12).
    TOGGLE AG2.
    WAIT 5.
    
    PRINT "Analyzing seismic activity...         " AT (0, 12).
    TOGGLE AG3.
    WAIT 5.

    PRINT "Reading barometrics and temperature..." AT (0, 12).
    TOGGLE AG4.
    WAIT 5.

    PRINT "Scientific analysis terminated.       " AT (0, 12).

    // Transmit all data to Kerbin.
    FOR p IN SHIP:PARTS {
        IF p:HASMODULE("ModuleScienceExperiment") {
            LOCAL scienceModule IS p:GETMODULE("ModuleScienceExperiment").
            IF scienceModule:HASDATA {
                scienceModule:TRANSMIT().
                WAIT 1.
            }
        }
    }
}

PRINT "Data transmission complete.           " AT (0, 12).

FUNCTION printFlightData {
    PARAMETER currentWP, currentPlanet, currentPosition.

    LOCAL targetGeo IS currentWP:GEOPOSITION.
    LOCAL distance IS targetGeo:DISTANCE.
    LOCAL speed IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL etaString IS "".
    LOCAL currentPlanet IS SHIP:BODY.
    LOCAL currentPosition IS SHIP:GEOPOSITION.
    LOCAL terrainElevation IS ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
    LOCAL terrainSlope IS ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
    LOCAL terrainBiome IS ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).
    
    IF speed > 0.2 {
        LOCAL totalSeconds IS distance / speed.
        LOCAL minutes IS FLOOR(totalSeconds / 60).
        LOCAL seconds IS FLOOR(totalSeconds - (minutes * 60)).
        LOCAL secString IS "" + seconds.
    
        IF seconds < 10 { SET secString TO "0" + seconds. }
        SET etaString TO minutes + "m " + secString + "s".
    } ELSE {
        SET secString TO "N/A Drone Stopped.".
    }

    PRINT "=== NAVIGATION AND TELEMETRY DATA ===" AT (0, 14).
    PRINT " Planet: " + SHIP:BODY:NAME AT (0, 15).
    PRINT " Coordinates: " + ROUND(currentPosition:LAT, 2) + ", " + ROUND(currentPosition:LNG, 2) AT (0, 16).
    PRINT " Elevation: " + terrainElevation + "m" AT (0, 17).
    PRINT " Slope: " + ROUND(terrainSlope, 2) + "%" AT (0, 18).
    PRINT " Biome: " + terrainBiome AT (0, 19).
    PRINT " Distance to Waypoint: " + ROUND(distance, 1) + "m      " AT (0, 20).
    PRINT " Current Ground Speed: " + ROUND(speed, 1) + "m/s    " AT (0, 21).
    PRINT " Estimated Arrival On: " + etaString + "           " AT (0, 22).
    PRINT "=====================================" AT (0, 23).

}

// End of script
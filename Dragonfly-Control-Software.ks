// Dragonfly Control Software

SET CONFIG:IPU TO 2000. // Sets instructions per update to max value (2000) for max performance.
GLOBAL flightMode IS "LIFTOFF". // Activates the main control loop.

// PID Controllers
GLOBAL alt_pid IS PIDLOOP(0.05, 0.005, 0.1, 0, 1). // Controls throttle.
GLOBAL vs_pid IS PIDLOOP (0.1, 0.01, 0.05, 0, 1). // Controls vertical speed.
GLOBAL speed_pid IS PIDLOOP (0.8, 0.005, 0.3, -15, 45). // Controls pitch.

PRINT "Dragonfly Control Software Initiated.".
WAIT 3.

// Target Altitude Menu
CLEARSCREEN.
LOCAL altString IS "".
PRINT "Enter your target altitude in meters: " AT (0, 1). // Prompts the user to enter its target altitude.

UNTIL FALSE {
    LOCAL enterAlt IS TERMINAL:INPUT:GETCHAR(). // Captures the user's input for target altitude.

    IF enterAlt = TERMINAL:INPUT:ENTER {
        BREAK.
    }
    ELSE IF enterAlt = TERMINAL:INPUT:BACKSPACE {
        IF altString:LENGTH > 0 {
            SET altString TO altString:SUBSTRING(0, altString:LENGTH - 1). // Removes the last captured character every time the user presses backspace.
            CLEARSCREEN.
            PRINT "Enter your target altitude in meters: " AT (0, 1).
        }
    } ELSE {
        SET altString TO altString + enterAlt.
        CLEARSCREEN.
        PRINT "Enter your target altitude in meters: " + altString AT (0, 1).
    }
}

GLOBAL targetAlt IS altString:TONUMBER(500). // Defaults to 500 meters if a letter is accidentally entered.

// Waypoint Search Function
LOCAL wpList IS LIST(). // Creates a list of all found waypoints on the drone's current planet.
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
    LOCAL userInput IS TERMINAL:INPUT:GETCHAR(). // Captures the waypoint number the user selected.
    LOCAL userNum IS userInput:TONUMBER(-1). //Returns -1 if input is invalid.
    
    IF userNum >=0 AND userNum < wpList:LENGTH {
        SET currentWP TO wpList[userNum].
        SET validChoise TO TRUE.
    } ELSE {
        PRINT "Invalid choise. Please select a number from the list above.".
    }
}

CLEARSCREEN.
PRINT "Target altitude: " + targetAlt + "m" AT (0, 2).
PRINT "Target Locked: " + currentWP:NAME AT (0, 3).
PRINT "Activating Autopilot..." AT (0, 4).
WAIT 5.

// Main Control Loop
// Works by calling the functions below.
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

executeScienceSequence(). // Activates the scientific analysis sequence once drone is landed.

// Flight Control Functions
// DISCLAIMER: DO NOT MODIFY OR DELETE UNLESS YOU KNOW WHAT YOU'RE DOING.

FUNCTION Liftoff {
    PRINT "Flight Mode: Liftoff          " AT (0, 6).
    LOCK STEERING TO HEADING(currentWP:GEOPOSITION:HEADING, 0). // Locks the drone's heading to the target waypoint.
    LOCK THROTTLE TO 0.33.

    WAIT UNTIL ALT:RADAR >= 100. // At 100 meters over the ground, activates the Cruise Function.
    PRINT "Transitioning to Cruise Mode.              " AT (0, 8).
}

FUNCTION Cruise {
    PRINT "Flight Mode: Cruise           " AT (0, 6).
    LOCAL targetHeading IS currentWP:GEOPOSITION:HEADING.
    LOCAL cruiseSpeed IS 40.
    LOCAL cruisePitch IS 0.
    LOCAL pitchSmoothing IS 0.075.
    LOCAL altitudeRange IS 5.

    SET speed_pid:SETPOINT TO 45. // Sets the drone's pitch to -45 degrees for best performance.

    LOCAL rawThrottle IS 1.0.

    // Approach Mode Activation Variables
    LOCAL maxPitchDown IS -45.
    LOCAL maxPitchUp IS 15.
    LOCAL descentAngle IS 45.
    LOCAL horizontalDistance IS targetAlt / TAN(descentAngle).
    LOCAL triggerDist IS SQRT(targetAlt^2 + horizontalDistance^2). // When this values is less than or equal to the distance to the target waypoint, activates the Approach Function.

    LOCAL cruiseStart IS TIME:SECONDS.
    LOCAL pitchDuration IS 20.
    LOCAL maxPitchRate IS 5.

    speed_pid:RESET().
    SET speed_pid:SETPOINT TO 0.
    
    LOCAL currentPlanet IS SHIP:BODY.
    LOCAL currentPosition IS SHIP:GEOPOSITION.

    // Safety net designed to not allow the drone to start aprroaching if it has not reached its target altitude.
    UNTIL currentWP:GEOPOSITION:DISTANCE <= triggerDist AND SHIP:ALTITUDE >= targetAlt - altitudeRange {
        LOCAL horizontalVelocity IS VXCL(UP:VECTOR, SHIP:VELOCITY:SURFACE).
        LOCAL facingVector IS HEADING(targetHeading, 0):FOREVECTOR.
        LOCAL forwardSpeed IS VDOT(horizontalVelocity, facingVector).
        LOCAL pitchTime IS MIN(pitchDuration, TIME:SECONDS - cruiseStart).
        LOCAL pitchSpeed IS cruiseSpeed * SQRT(pitchTime / pitchDuration).

        SET alt_pid:SETPOINT TO targetAlt. // Target altitude above sea level.
        SET speed_pid:SETPOINT TO pitchSpeed.

        LOCAL targetPitch IS -1 * speed_pid:UPDATE(TIME:SECONDS, forwardSpeed).
        LOCAL maxDelta IS maxPitchRate * 0.1.

        IF targetPitch > cruisePitch {
            SET cruisePitch TO MIN(cruisePitch + maxDelta, targetPitch).
        } ELSE {
            SET cruisePitch TO MAX(cruisePitch - maxDelta, targetPitch).
        }
        
        IF cruisePitch < maxPitchDown {
            SET cruisePitch TO maxPitchDown.
        }
        ELSE IF cruisePitch > maxPitchUp {
           SET cruisePitch TO maxPitchUp. 
        }

        SET targetHeading TO currentWP:GEOPOSITION:HEADING.
        SET rawThrottle TO alt_pid:UPDATE(TIME:SECONDS, ALTITUDE). // Maintains the drone's altitude at the target altitude with help from the alt_pid.

        LOCK STEERING TO HEADING(targetHeading, cruisePitch).
        LOCK THROTTLE TO MAX(0.20, rawThrottle). // Maintains the drone's throttle either at the alt_pid output or an idle throttle of 0.2.

        altitudeCheck(). // Checks if altitude is within safety parameter with every loop execution.
            
        SET terrainElevation TO ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
        SET terrainSlope TO ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
        SET terrainBiome TO ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).
        
        printFlightData(currentWP, currentPlanet, currentPosition).

        WAIT 0.1.
    }
    PRINT "Transitioning to Approach Mode.            " AT (0, 8).
    cruiseTelemetryAnalysis().
}

FUNCTION Approach {
    PRINT "Flight Mode: Approach         " AT (0, 6).
    LOCAL targetHeading IS currentWP:GEOPOSITION:HEADING.

    LOCAL rawThrottle IS 1.0.
    LOCAL idleThrottle IS 0.1.
    LOCAL maxThrottle IS 0.375.
    LOCAL current_pitch IS -30.
    LOCAL maxPitchDown IS -45.
    LOCAL maxPitchUp IS 15.
    LOCAL maxPitchRate IS 5.
    LOCAL groundDistance IS currentWP:GEOPOSITION:DISTANCE.
    LOCAL horizontalDistance IS SQRT(MAX(0, groundDistance^2 - ALTITUDE^2)).
    LOCAL minDistance IS horizontalDistance.
    LOCAL minApproachAlt IS 50.
    LOCAL descentAngle IS 45.

    speed_pid:RESET().
    SET speed_pid:SETPOINT TO -30.

    LOCAL currentPlanet IS SHIP:BODY.
    LOCAL currentPosition IS SHIP:GEOPOSITION.

    // Activates the Land Function once drone has descended to 100 meters over ground level.
    UNTIL ALT:RADAR < 100 {
        SET groundDistance TO currentWP:GEOPOSITION:DISTANCE.
        SET horizontalDistance TO SQRT(MAX(0, groundDistance^2 - ALTITUDE^2)).
    
        IF horizontalDistance < minDistance {
            SET minDistance TO horizontalDistance.
        }
    
        IF minDistance < 2 {
            SET minDistance TO 0.
        }

        LOCAL descentAlt IS MAX(minApproachAlt, horizontalDistance / TAN(descentAngle)).
        SET alt_pid:SETPOINT TO MIN(targetAlt, descentAlt).
        
        LOCAL dynamicSpeed IS SQRT(minDistance) * 0.75.
    
        SET speed_pid:SETPOINT TO dynamicSpeed.

        LOCAL targetPitch IS -1 * speed_pid:UPDATE(TIME:SECONDS, SHIP:VELOCITY:SURFACE:MAG).
        LOCAL maxDelta IS maxPitchRate * 0.1.

        IF targetPitch > current_pitch {
            SET current_pitch TO MIN(current_pitch + maxDelta, targetPitch).
        } ELSE {
            SET current_pitch TO MAX(current_pitch - maxDelta, targetPitch).
        }

        IF current_pitch < maxPitchDown {
            SET current_pitch TO maxPitchDown.
        } 
        ELSE IF current_pitch > maxPitchUp {
            SET current_pitch TO maxPitchUp.
        }
        
        SET rawThrottle TO alt_pid:UPDATE(TIME:SECONDS, ALTITUDE).

        LOCAL descentFactor IS MAX(0, MIN(1, -current_pitch / ABS(maxPitchDown))). // Makes the drone descend at an angle of -45 degrees. In other words, for every meter the drone moves forward, it must descend 1 meter.
        LOCAL brakeThrottle IS maxThrottle -descentFactor * (maxThrottle - idleThrottle).
        
        LOCK STEERING TO HEADING(targetHeading, current_pitch).
        LOCK THROTTLE TO MAX(brakeThrottle, rawThrottle). // Maintains the drone's throttle between the alt_pid output or the needed throttle level to decelerate.

        SET terrainElevation TO ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
        SET terrainSlope TO ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
        SET terrainBiome TO ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).

        printFlightData(currentWP, currentPlanet, currentPosition).

        WAIT 0.1.
    }
    PRINT "Transitioning to Landing Mode.             " AT (0, 8).
}

FUNCTION Land {
    PRINT "Flight Mode: Landing          " AT (0, 6).
    
    LOCAL lockedHeading IS MOD(360 - LATLNG(90, 0):BEARING, 360). // Locks the drone's current heading to maintain orientation while landing.
    
    LOCAL currentPlanet IS SHIP:BODY.
    LOCAL currentPosition IS SHIP:GEOPOSITION.
    LOCAL terrainElevation IS ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
    LOCAL terrainSlope IS ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
    LOCAL terrainBiome IS ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).

    speed_pid:RESET().
    SET speed_pid:SETPOINT TO 0.
    vs_pid:RESET().

    UNTIL SHIP:STATUS = "LANDED" {
        LOCAL horizontalVelocity IS VXCL(UP:VECTOR, SHIP:VELOCITY:SURFACE).
        LOCAL facingVector IS HEADING(lockedHeading, 0):FOREVECTOR.
        LOCAL forwardSpeed IS VDOT(horizontalVelocity, facingVector).
        LOCAL rawPitch IS -1 * speed_pid:UPDATE(TIME:SECONDS, forwardSpeed).
        LOCAL brakePitch IS MIN(15, MAX(-15, rawPitch)).
        LOCAL targetVS IS -1 * MAX(0.5, MIN(3.5, 0.7 * SQRT(ALT:RADAR))).
        LOCAL rawThrottle IS vs_pid:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).

        IF ABS(forwardSpeed) < 0.25 {
            SET rawPitch TO 0.
            speed_pid:RESET().
        }

        LOCK STEERING TO HEADING(lockedHeading, brakePitch). // Makes the drone lift its nose the requiered amount to reduce horizontal velocity to almost 0.
        LOCK THROTTLE TO MAX(0.15, rawThrottle).

        SET vs_pid:SETPOINT TO targetVS. // Constantly adjusts throttle in order to softly land around 0.5 - 1.0 m/s.

        SET terrainElevation TO ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
        SET terrainSlope TO ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
        SET terrainBiome TO ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).
            
        printFlightData(currentWP, currentPlanet, currentPosition).

        WAIT 0.1.
    }    
    
    stabilityCheck().
}

// Additional Functions

// Prints telemetry and ETA data in the terminal.

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

    PRINT "=== NAVIGATION AND TELEMETRY DATA ===" AT (0, 12).
    PRINT " Planet: " + SHIP:BODY:NAME AT (0, 13).
    PRINT " Coordinates: " + ROUND(currentPosition:LAT, 2) + ", " + ROUND(currentPosition:LNG, 2) + "     "AT (0, 14).
    PRINT " Elevation: " + terrainElevation + "m     " AT (0, 15).
    PRINT " Slope: " + ROUND(terrainSlope, 2) + "     " AT (0, 16).
    PRINT " Biome: " + terrainBiome + "          " AT (0, 17).
    PRINT " Distance to Waypoint: " + ROUND(distance, 1) + "m      " AT (0, 18).
    PRINT " Current Ground Speed: " + ROUND(speed, 1) + "m/s    " AT (0, 19).
    PRINT " Estimated Arrival On: " + etaString + "           " AT (0, 20).
    PRINT "=====================================" AT (0, 21).
}

// Checks if the drone landed on stable ground by setting pitch and roll limits.

FUNCTION stabilityCheck {
    PRINT "Flight Mode: Stability Check  " AT (0, 6).
    PRINT "Checking is ground is level...             " AT (0, 8).

    LOCK THROTTLE TO 0.
    UNLOCK STEERING.

    LOCAL standbyTime IS TIME:SECONDS.
    LOCAL abortLanding IS FALSE.

    LOCAL currentPlanet IS SHIP:BODY.
    LOCAL currentPosition IS SHIP:GEOPOSITION.
    LOCAL terrainElevation IS ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
    LOCAL terrainSlope IS ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
    LOCAL terrainBiome IS ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).

    UNTIL TIME:SECONDS > standbyTime + 5 {
        LOCAL abortPitch IS 90 - VANG(UP:VECTOR, SHIP:FACING:FOREVECTOR).
        LOCAL abortRoll IS 90 - VANG(UP:VECTOR, SHIP:FACING:STARVECTOR).

        SET terrainElevation TO ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
        SET terrainSlope TO ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
        SET terrainBiome TO ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).

        printFlightData(currentWP, currentPlanet, currentPosition).

        IF ABS(abortPitch) > 45 OR ABS(abortRoll) > 30 {
            SET abortLanding TO TRUE.
            BREAK.
        }
        
        WAIT 0.1.
    }

    IF abortLanding = TRUE {
        PRINT "Flight Mode: EMERGENCY TAKEOFF" AT (0, 6).
        PRINT "UNSTABLE GROUND DETECTED. EMERGENCY TAKEOFF" AT (0, 8).

        landingAbort().
    } ELSE {
        PRINT "Touchdown Confirmed. Safely Landed.        " AT (0, 8).
        
        LOCK THROTTLE TO 0.
        UNLOCK STEERING.
        UNLOCK THROTTLE.
    }
}

// Makes the drone take off again and fly straight for 30 seconds to avoid rolling down mountains.

FUNCTION landingAbort {
    LOCAL lockedHeading IS MOD(360 - LATLNG(90, 0):BEARING, 360).
    LOCAL flightTime IS TIME:SECONDS.

    LOCK STEERING TO HEADING(lockedHeading, 0).
    LOCK THROTTLE TO 1.0.

    SET alt_pid:SETPOINT TO 100. // Maintains a 100-meter altitude while switching landing zone.

    PRINT "Ascending to a safe altitude.         " AT (0, 10).

    LOCAL currentPlanet IS SHIP:BODY.
    LOCAL currentPosition IS SHIP:GEOPOSITION.
    LOCAL terrainElevation IS ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
    LOCAL terrainSlope IS ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
    LOCAL terrainBiome IS ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).

    // Change this value if you want longer or shorter flight time during abort.
    UNTIL TIME:SECONDS > flightTime + 30 {
        LOCAL rawThrottle IS alt_pid:UPDATE(TIME:SECONDS, ALT:RADAR).
        
        LOCK STEERING TO HEADING(lockedHeading, -15).
        LOCK THROTTLE TO MAX(0.15, rawThrottle).

        SET terrainElevation TO ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
        SET terrainSlope TO ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
        SET terrainBiome TO ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).

        printFlightData(currentWP, currentPlanet, currentPosition).

        WAIT 0.1.
    }

    PRINT "Attempting safe landing.                   " AT (0, 10).
    WAIT 1.

    Land().
}

// Constantly evaluates distance to the ground and maintains a safety margin of 500 meters until altitude stabilizes.

FUNCTION altitudeCheck {
    LOCAL safeAltitude IS 500.
    LOCAL targetHeading IS currentWP:GEOPOSITION:HEADING.
    LOCAL altitudeRange IS 5.
    LOCAL current_pitch IS -45.
    LOCAL isManeuvering IS FALSE.
    
    LOCAL currentPlanet IS SHIP:BODY.
    LOCAL currentPosition IS SHIP:GEOPOSITION.
    LOCAL terrainElevation IS ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
    LOCAL terrainSlope IS ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
    LOCAL terrainBiome IS ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).

    IF ALT:RADAR < safeAltitude {
        IF SHIP:ALTITUDE <= targetAlt + altitudeRange AND SHIP:ALTITUDE >= targetAlt - altitudeRange {
            SET isManeuvering TO TRUE.
            PRINT "Unsafe altitude detected. Ascending.  " AT (0, 10).
            
            UNTIL isManeuvering = FALSE {
                LOCAL rawThrottle IS alt_pid:UPDATE(TIME:SECONDS, ALT:RADAR).

                SET alt_pid:SETPOINT TO 500.
                
                LOCK STEERING TO HEADING(targetHeading, current_pitch).
                LOCK THROTTLE TO MAX(0.15, rawThrottle).

                IF ALT:RADAR <= safeAltitude + altitudeRange AND ALT:RADAR >= safeAltitude - altitudeRange {
                    IF SHIP:ALTITUDE <= targetAlt + altitudeRange AND SHIP:ALTITUDE >= targetAlt - altitudeRange {
                        SET isManeuvering TO FALSE.
                    }
                }

                SET terrainElevation TO ADDONS:SCANSAT:ELEVATION(currentPlanet, currentPosition).
                SET terrainSlope TO ADDONS:SCANSAT:SLOPE(currentPlanet, currentPosition).
                SET terrainBiome TO ADDONS:SCANSAT:GETBIOME(currentPlanet, currentPosition).

                printFlightData(currentWP, currentPlanet, currentPosition).

                WAIT 0.1.
            }            
        }
    }

    PRINT "Dragonfly is within safe altitude.    " AT (0, 10).
}

// Scientific Analysis Functions

FUNCTION cruiseTelemetryAnalysis {
    PRINT "Analyzing telemetry data...           " AT (0, 10).
    TOGGLE AG5.
    PRINT "Flight analysis complete.             " AT (0, 10).
}

FUNCTION executeScienceSequence {
    PRINT "Initiating scientific analysis...     " AT (0, 10).
    SET current_throttle TO 0.

    PRINT "Deploying sampling drill...           " AT (0, 10).
    TOGGLE AG1.
    WAIT 10.
    
    PRINT "Analyzing gravitational activity...   " AT (0, 10).
    TOGGLE AG2.
    WAIT 5.
    
    PRINT "Analyzing seismic activity...         " AT (0, 10).
    TOGGLE AG3.
    WAIT 5.

    PRINT "Reading barometrics and temperature..." AT (0, 10).
    TOGGLE AG4.
    WAIT 5.

    PRINT "Scientific analysis terminated.       " AT (0, 10).

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

PRINT "Data transmission complete.           " AT (0, 10).


// End of script
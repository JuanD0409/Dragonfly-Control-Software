// Dragonfly Control Software

GLOBAL flightMode IS "LIFTOFF".

// PID Controllers
GLOBAL alt_pid IS PIDLOOP(0.05, 0.005, 0.1, 0, 1).
GLOBAL vs_pid IS PIDLOOP (0.1, 0.01, 0.05, 0, 1).
GLOBAL speed_pid IS PIDLOOP (0.3, 0.01, 0.275, 0, 45).

// Waypoint Search Function
LOCAL wpList IS LIST().
FOR wp IN ALLWAYPOINTS() {
    IF wp:BODY = SHIP:BODY {
        wpList:ADD(wp).
    }
}

IF wpList:LENGTH = 0 {
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

FUNCTION Liftoff {
    PRINT "Flight Mode: Liftoff " AT (0, 10).
    LOCK STEERING TO HEADING(currentWP:GEOPOSITION:HEADING, 0).
    LOCK THROTTLE TO 0.33.

    WAIT UNTIL ALT:RADAR >= 100.
    PRINT "Transitioning to Cruise Mode.      " AT (0, 12).
}

FUNCTION Cruise {
    PRINT "Flight Mode: Cruise  " AT (0, 10).
    LOCAL targetHeading IS currentWP:GEOPOSITION:HEADING.

    SET alt_pid:SETPOINT TO 5250. // Target altitude above sea level.
    SET speed_pid:SETPOINT TO 50. // Target forward speed in m/s.

    LOCAL current_throttle IS 1.0.
    LOCAL current_pitch IS 0.

    LOCK STEERING TO HEADING(targetHeading, current_Pitch).
    LOCK THROTTLE TO current_throttle.

    // Approach Mode Activation Variables and Commands
    LOCAL gravity IS BODY:MU / BODY:RADIUS ^2.
    LOCAL maxPitch IS 45.
    LOCAL craftBrake IS gravity * TAN(maxPitch).
    LOCAL aeroBrake IS 3.0. // Adjust this number based on current planet's atmospheric density.
    LOCAL totalBrake IS craftBrake + aeroBrake.
    LOCAL targetSpeed IS speed_pid:SETPOINT.
    LOCAL brakeDist IS (targetSpeed^2) / (2 * totalBrake).
    LOCAL approachDist IS brakeDist * 1.2.

    PRINT "Approach Activation Calulated: " + ROUND(approachDist, 1) + "m".

    LOCAL groundDist IS VXCL(UP:VECTOR, currentWP:GEOPOSITION:POSITION):MAG.

    UNTIL groundDist <= approachDist {
        SET targetHeading TO currentWP:GEOPOSITION:HEADING.
        SET current_pitch TO -1 * speed_pid:UPDATE(TIME:SECONDS, SHIP:VELOCITY:SURFACE:MAG).
        SET current_throttle TO alt_pid:UPDATE(TIME:SECONDS, ALTITUDE).
        WAIT 0.1.
    }
    PRINT "Transitioning to Approach Mode.    " AT (0, 12).
}

FUNCTION Approach {
    PRINT "Flight Mode: Approach" AT (0, 10).
    LOCAL targetHeading IS currentWP:GEOPOSITION:HEADING.

    SET speed_pid:SETPOINT TO 0.
    SET vs_pid:SETPOINT TO -5.

    LOCAL current_throttle IS 0.25.
    LOCAL current_pitch IS 0.

    LOCK STEERING TO HEADING(targetHeading, current_pitch).
    LOCK THROTTLE TO current_throttle.

    UNTIL SHIP:VELOCITY:SURFACE:MAG < 1 {
        SET targetHeading TO currentWP:GEOPOSITION:HEADING.
        SET current_pitch TO -1 * speed_pid:UPDATE(TIME:SECONDS, SHIP:VELOCITY:SURFACE:MAG).
        SET current_throttle TO vs_pid:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).
        WAIT 0.1.
    }
    PRINT "Transitioning to Landing.          " AT (0, 12).
}

FUNCTION Land {
    PRINT "Flight Mode: Landing  " AT (0, 10).
    LOCAL targetHeading IS currentWP:GEOPOSITION:HEADING.
    LOCAL current_throttle IS 0.2.

    LOCK STEERING TO HEADING(targetHeading, 0).
    LOCK THROTTLE TO current_throttle.

    UNTIL SHIP:STATUS = "LANDED" {
        IF ALT:RADAR > 20 {
            SET vs_pid:SETPOINT TO -3.
        } ELSE {
            SET vs_pid:SETPOINT TO -1.
        }
        SET current_throttle TO vs_pid:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).
        WAIT 0.1.
    }
    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    PRINT "Touchdown Confirmed. Safely Landed." AT (0, 12).
}
// Dragonfly Control Software

@LAZYGLOBAL OFF.

// PID Controllers
GLOBAL pid_alt IS PIDLOOP(0.2, 0.01, 0.1, -10, 10).
GLOBAL pid_vs IS PIDLOOP(0.05, 0.01, 0.05, 0, 1).
GLOBAL pid_pitch IS PIDLOOP(1.5, 0.1, 0.5, -45, 5).

// Flight Control Parameters
PARAMETER targetAlt IS 5000.
PARAMETER cruiseSpeed IS 40.
PARAMETER approachDist IS 250.

CLEARSCREEN.
PRINT "Dragonfly Control Software Initializing...".

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

// Flight Varibles
GLOBAL flightMode IS "LIFTOFF".
GLOBAL desiredVS IS 0.
GLOBAL throttleCMD IS 0.
GLOBAL targetPitch IS 0.
GLOBAL forwardSpeed IS 0.
GLOBAL dynamicHeading IS 90.
GLOBAL targetDir IS HEADING(dynamicHeading, -targetPitch):VECTOR.

// Control Locks
LOCK STEERING TO LOOKDIRUP(targetDir, SHIP:UP:VECTOR).
LOCK THROTTLE TO throttleCMD.

// Main Control Loop
UNTIL flightMode = "ARRIVED" {
    LOCAL targetGeo IS currentWP:GEOPOSITION.
    SET dynamicHeading TO targetGeo:HEADING.
    LOCAL distToTarget IS targetGeo:DISTANCE.
    
    LOCAL facingVector IS HEADING(dynamicHeading, 0):VECTOR.
    SET forwardSpeed TO VDOT(SHIP:VELOCITY:SURFACE, facingVector).
    
    IF flightMode = "LIFTOFF" { SET flightMode TO Liftoff(). }
    ELSE IF flightMode = "CRUISE" { SET flightMode TO Cruise(distToTarget). }
    ELSE IF flightMode = "APPROACH" { SET flightMode TO Approach(). }
    ELSE IF flightMode = "LANDING" { SET flightMode TO Landing(). }

    IF flightMode = "CRUISE" OR flightMode = "APPROACH" OR flightMode =  "LANDING" {
        SET desiredVS TO pid_alt:UPDATE(TIME:SECONDS, ALT:RADAR).
        SET pid_vs:SETPOINT TO desiredVS.
        SET throttleCMD TO pid_vs:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).
    }
    WAIT 0.1.
}

// Shutdown Sequence
UNLOCK STEERING.
LOCK THROTTLE TO 0.
SET SHIP:CONTROL:THROTTLE TO 0.
WAIT 1.
UNLOCK THROTTLE.

PRINT "Dragonfly waypoint reached. Systems unlocked.".

// Function List

FUNCTION Liftoff {
    SET targetPitch TO 0.
    SET throttleCMD TO 0.33.

    IF ALT:RADAR > (targetAlt - 5) {
        PRINT "Cruising altitude reached. En route to: " + currentWP:NAME.
        pid_alt:RESET().
        pid_vs:RESET().
        RETURN "CRUISE".
    }
    RETURN "LIFTOFF".
}

FUNCTION Cruise {
    PARAMETER distToTarget.

    SET pid_alt:SETPOINT TO targetAlt.
    SET desiredVS TO pid_alt:UPDATE(TIME:SECONDS, ALT:RADAR).

    SET pid_pitch:SETPOINT TO cruiseSpeed.
    SET targetPitch TO pid_pitch:UPDATE(TIME.SECONDS, forwardSpeed).

    IF distToTarget < approachDist {
        PRINT "Approaching target (" + ROUND(distToTarget, 0) + "m away). Decelerating...".
        RETURN "APPROACH".
    }
    RETURN "CRUISE".
}

FUNCTION Approach {
    SET pid_pitch:SETPOINT TO 0.
    SET targetPitch TO pid_pitch:UPDATE(TIME:SECONDS, forwardSpeed).

    SET pid_alt:SETPOINT TO targetAlt.
    SET desiredVS TO pid_alt:UPDATE(TIME:SECONDS, ALT:RADAR).

    IF forwardSpeed < 1 AND forwardSpeed > -1 {
        PRINT "Positioned over " + currentWP:NAME + ". Initiating vertical descent.".
        RETURN "LANDING".
    }
    RETURN "APPROACH".
}

FUNCTION Landing {
    SET pid_pitch:SETPOINT TO 0.
    SET targetPitch TO pid_pitch:UPDATE(TIME:SECONDS, forwardSpeed).

    IF ALT:RADAR > 50 {
        SET pid_alt:SETPOINT TO 20.
        SET desiredVS TO pid_alt:UPDATE(TIME:SECONDS, ALT:RADAR).
    } ELSE IF ALT:RADAR > 10 {
        SET desiredVS TO -2.
    } ELSE {
        SET desiredVS TO -0.5.
    }

    IF SHIP:STATUS = "LANDED" {
        PRINT "Landed at " + currentWP:NAME.
        RETURN "ARRIVED".
    }
    RETURN "LANDING".
}

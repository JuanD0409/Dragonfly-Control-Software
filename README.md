# Dragonfly-Control-Software
A program written in KerboScript to control a drone in Kerbal Space Program based on NASA's Dragonfly mission.

## Quick Start Guide
1. Copy the code on the "Dragonfly-Control-Software.ks" file.
2. Open the kOS Terminal and type the command "EDIT drone.script.". A window with the name "drone.script" should appear below the terminal; paste the code there and save it.
3. Run the code and follow the prompts that appear on the terminal, the drone will then operate on its own.

## Features
* Waypoint-based Navigation and Selection Menu
* Autonomous Liftoff, Cruise, Approach and Landing Sequence
* Landing Abort and Safe Altitude Maintenance for crash avoidance
* Proportional-Integral-Derivative (PID) Applications
* Scientific Analysis Sequence and Data Transmission
* Remaining Distance, Current Speed, and ETA Calculator and Display
* Telemetry statistics using SCANsat

## Local Deployment Requirements and Tutorial

### Requirements (as tested)
* Kerbal Space Program v1.12.5.3190 
* Breaking Ground DLC v1.7.1
* kerbal Operating System (kOS) v1.6.0.1
* Infernal Robotics-Next v3.1.22
* Dependencies of Mods Installed: Latest Compatible Version

Note: KerboScript compatibility is integrated with any kOS version.

### Recommendations (as tested)
* kOS for All! v0.0.5
* SCANsat v21.1
* Bluedog Design Bureau v1.14.0
* Near Future Exploration v1.1.3
* Neptune Camera v4.3
* Outer Planets Mod v2.2.2.12
* Dependencies of Mods Installed: Latest Compatible Version

### Required Drone Characteristics
* Power Generator and Storage
* Rotors with propellers that give at least 1.2 Thrust-to-Weight Ratio (TWR)
* Forward-Facing Probe Core (for optimal response)
* Landing Legs with Shock Absorbers
* Antenna for Communications
* Kerbnet Access or SCANsat maps (Kerbnet Access is required for waypoint marking; SCANsat maps can also be used)
* kOS-enabled Probe Core or module

### Additional Recommended Drone Characteristics
* Scientific Instruments
* SCANsat Radars, Cameras, and other Instruments

### Local Deployment Guide
1. While controlling the drone you want to automate, follow the Quick Start Guide.
2. Type the command "RUN drone.script(desired altitude)." in the kOS terminal and follow any prompt. Type the desired altitude for the drone to reach between the parentheses. If the user does not enter the desired altitude within the parentheses, kOS will throw an error in terminal explaining that the code has not the expected amount of arguments to run correctly. 
3. Select the waypoint you want your drone to reach. If there are no waypoints, an error message will appear on the terminal explaining that at least one waypoint is required to run. Otherwise, the code will not run since the navigation control functionality will not be able to operate adequately.
4. After the selected waypoint is targeted, the drone will then liftoff, cruise, approach, and land on its own.

## Script Functionality

### Navigation and Control

The script is designed to automate the liftoff, cruise, approach, and landing sequences of a drone-like craft based on NASA's Dragonfly rotorcraft, although it can be used with anything that can fly with rotors. Its functioning includes throttle and altitude control, pitch and heading control, Proportional-Integral-Derivative (PID) controllers, and waypoint and altitude selection. At startup, the program is made to ask the user its target atlitude and print a coded UI on the terminal that prompts the user for a waypoint to target. If none are found within the current planet, an error message appears on the terminal. When a waypoint is targeted, the script calculates its target heading, sets its pitch angle to 0, takes off from the ground at an established throttle of 33%, and aligns with its target waypoint. After reaching 100 meters above ground level, the drone pitches to -45 degrees and sets full throttle until reaching the established target altitude. Once the drone reaches its target altitude, it cruises until triggering its approach sequence; the drone then makes a certain calculation to start descending at a -45 degree angle toward the waypoint. When this happens, the program also triggers its mid-flight telemetry analysis (see section below for more info). Once the drone is 100 meters over ground level, it activates its landing procedure, which lifts its nose up to 15 degrees upward and increases its throttle to cancel horizontal velocity almost completely and reduce vertical speed to around 0.5 - 1.0 m/s.  After softly landing, it initiates its scientific analysis and data transmission procedure. The PID controllers are made to give stability and to control aspects such as pitch angle, altitude corrections, and throttle adjustments. The script also has functions to avoid crashes. One of these is a landing abort system that works by evaluating if the drone exceeds angles of 45 degrees for pitch and 30 degrees for roll. If so happens, the drone lifts off at full power and maintains an altitude of 100 meters over ground level. Then, it navigates in a straight, locked heading for 30 seconds until attempting to land again. If the terrain the drone landed at does not exceed its angle limits, it simply activates its scientific analysis procedure; otherwise, if the terrain does exceed its limits again, it takes off and changes its landing site as many times as needed to not roll down a mountain. The other safety function is made to avoid crashing into a mountain when flying at low altitudes. It constantly evaluates if the drone is flying within a 10-meter margin around its target altitude and the distance from the ground goes below 500 meters. If both conditions are true, the drone maintains a 500-meter distance from the ground until its altitude over sea level reaches the 10-meter margin around the target altitude and its altitude over ground level goes higher than 500 meters. Aside from the navigation control aspects, the script also has two functions integrated to show data in the terminal. The first function is made to show current speed, remaining distance to the target waypoint, and, based on this data, calculate and show the estimated time of arrival. The second function is designed to take data from SCANsat and show it to the user in the terminal alongside the ETA and remaining distance data. The SCANsat data includes current planet, coordinates, elevation, slope, and biome.

Disclaimer: The test drone is flown at Tekto, a moon (inspired by Saturn's moon Titan) from the Outer Planets mod, where gravity is really low and atmospheric pressure is high; making it perfect for this type of rotorcraft. If flying in other planets or moons, adjustments should have to be made to the script. Also, re-check that your rotorcraft is able to take off, and reach its target altitude.

### Scientific Analysis Sequence

The main idea of this function is that the user should place scientific parts and/or modules in the craft in order for them to be activated by the code using action groups. The script's scientific analysis function is built to be fully customizable thanks to action groups. The code's functionality is composed of a sequence of PRINT, action group, and WAIT commands, whose purpose is to activate the scientific instruments placed by the user. The user is able to change what the PRINT commands show, the length of the WAIT commands (based on the instruments they place on the drone), and the order in which they are activated by the action groups. The recommended instruments are a sampling drill, surface scan machine, barometrics, seismograph, etc. Aside from this, the script also takes data from scientific instruments right after the Cruise UNTIL loop's conditionals are fulfilled. The idea is, if the user has SCANsat installed, to place the terrain-related scans to be realized when this action group activates. Therefore, the scans are done when the drone is at its target altitude, flying high over the surface.

## Credits and Acknowledgements
* Original kOS creator: Github user Nivekk (Kevin Laity).
* All 127 kOS developers and contributors.

# AlertGizmo

by Ian Kluft

AlertGizmo is software which monitors for space-related events and generate summary pages.

## Modules

The subclasses of AlertGizmo which handle the details of specific topics of space alert data are as follows:

* implemented
  * AlertGizmo::Neo - monitor for NASA JPL Near-Earth Object (NEO) close approach data
  * AlertGizmo::Swpc - monitor for NOAA Space Weather Prediction Center (SWPC) alerts, including aurora
* planned/work in progress
  * AlertGizmo::Apod - monitor for NASA Astronomy Picture of the Day (APOD) feed

## Source Code

It started with a [Perl implementation](src/perl) to be used as a prototype for other language implementations. The Perl modules were adapted from scripts I wrote to monitor space-related alerts online. The common code among the scripts was pulled together into the AlertGizmo module. These can be run manually, or automatically from crontabs. (An example is in the Perl source code directory.)

## To Do

I will make [the AlertGizmo subpage](https://ikluft.github.io/AlertGizmo/) on my github.io site display regularly-updated data fetched and processed by AlertGizmo modules, deployed via regularly-timed GitHub Actions and formatted with browser-side code. A [container holding the dependencies to build the web site](https://github.com/ikluft/AlertGizmo/tree/main/web-build/container) is in work.

### Examples

![Example of AlertGizmo::Neo output for NASA JPL near Earth object pass data](images/Screenshot-AlertGizmo-Neo-example.png)

![Example of AlertGizmo::Swpc output for NOAA Space Weather Prediction Center aurora data](images/Screenshot-AlertGizmo-Swpc-example.png)

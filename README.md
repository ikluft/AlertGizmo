# AlertGizmo

by Ian Kluft

AlertGizmo is software which monitors for space-related events and generate summary pages.

## Source Code

It started with a [Perl implementation](src/perl) to be used as a prototype for other language implementations. The Perl modules were adapted from scripts I wrote to monitor space-related alerts online. The common code among the scripts was pulled together into the AlertGizmo module. These can be run manually, or automatically from crontabs. (An example is in the Perl source code directory.)

## To Do

Make [the AlertGizmo subpage](https://ikluft.github.io/AlertGizmo/) on my github.io site display regularly-updated data fetched and processed by AlertGizmo modules, deployed via regularly-timed GitHub Actions and formatted with browser-side code. A [container holding the dependencies to build the web site](https://github.com/ikluft/AlertGizmo/tree/main/web-build/container) is in work.

### Examples

![Example of AlertGizmo::Neo output for NASA JPL near Earth object pass data](images/Screenshot-AlertGizmo-Neo-example.png)

![Example of AlertGizmo::Swpc output for NOAA Space Weather Prediction Center aurora data](images/Screenshot-AlertGizmo-Swpc-example.png)

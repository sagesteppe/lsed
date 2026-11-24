# Accessibility (A) and complementarity (C) on a road/trail network graph

A vector-first engine for the operational terms. Travel runs **on the
linestrings** - roads and trails as a weighted igraph, each edge timed
by its class speed - and only the **last hop** from the network to a
patch centroid drops to an off-trail Tobler cost. This sidesteps the
resolution trap of a friction raster (at 800 m a road is one fat cell)
and, because the patches become graph nodes, the same network answers
**C**
([`complementarity`](https://sagesteppe.github.io/lsed/reference/complementarity.md))
for free.

## Details

**Model.** Roads are the drive-to origins (reachable at zero walking
cost); from there a crew walks trails (`trail_speed`) and finally cuts
cross-country to the centroid at a slope-dependent Tobler speed.
Accessibility of a patch is the least-cost path origin -\> network -\>
hop, in hours.

**Noding.** OSM ways share vertex coordinates at junctions, so the graph
is built by snapping segment endpoints to a `snap`-metre grid - correct
for OSM topology. For arbitrary linework that crosses without shared
vertices, pre-node it (e.g.
[`sf::st_node`](https://r-spatial.github.io/sf/reference/geos_unary.html))
before calling.

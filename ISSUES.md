* no verticle scroll on the canvas
* ~~distance travelled doesn't work~~ FIXED:
  - GPX tracks are now processed through TelemetryCalculator after parsing to calculate distanceFromPrevious
  - "From Start" mode now correctly accumulates distance along the track (not straight-line distance)
  - Distance values now update correctly as the timeline scrubber moves
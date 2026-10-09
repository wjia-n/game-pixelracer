# Pixel Racer — Rules

## 1. Objective
Finish first. In Grand Prix the first driver to complete 3 laps wins.
In Time Trial the goal is the fastest laps against your own best. In Endless
Cruise the goal is maximum distance — 3 crashes ends the run.

## 2. Setup
- 1–2 human drivers + 0–3 AI rivals (Grand Prix needs at least 2 drivers
  total; Time Trial is always 1 human, 0 AI).
- Difficulty: Easy / Medium / Hard (Hard is Pro).
- AI rivals: Chill / Racer / Ace (Ace is Pro).
- Each driver picks a display name (persisted, renameable).
- Track: one of 8 shapes (4 free, 4 Pro). Car: one of 8 body styles
  (4 free, 4 Pro). Theme: one of 12 palettes + custom creator (Pro-gated).
- Grid: drivers start staggered just behind the start/finish line,
  alternating lanes.

## 3. Turn order
Real-time racing — there are no turns. All drivers move simultaneously at
60 physics steps per second. The countdown (3-2-1-GO) gates the start; no
driver may move before GO.

## 4. Legal moves
- Your car accelerates automatically; drag sideways to steer.
- Drifting: steering hard (|drag| large) at speed above 175 charges the
  drift meter. A full meter fires an automatic speed boost.
- With 2 humans: the left half of the screen steers driver 1, the right
  half steers driver 2.

## 5. Illegal moves
- Steering has no effect before GO, while paused, after finishing, or
  during a crash spin.
- There is no reverse and no teleporting: a car that leaves the road must
  drive back on.

## 6. Captures
N/A — no captures. (Near-miss overtakes award nothing but glory.)

## 7. Special rules
- **Checkpoints:** the track has 12 checkpoints. They must be crossed in
  order; a lap only counts when checkpoint 0 (start/finish) is crossed
  after checkpoints 1–11.
- **Off-road:** leaving the road surface slows the car (drag). In Endless
  Cruise, being off-road at speed for more than 0.6s causes a crash.
- **Crash:** a crashed car spins for 0.9s at zero speed, then recovers.
- **Rubber-banding:** AI rivals speed up slightly when far behind the
  leader and ease off slightly when far ahead, keeping every race close.
- **Drift boost:** a full drift meter converts to +130 speed burst for
  ~1.1s with flame visuals.

## 8. Scoring
- Grand Prix: places by finish order (1st across the line after 3 laps).
- Time Trial: best lap time (persisted as all-time best).
- Endless Cruise: distance in meters (persisted as all-time best).

## 9. Winning conditions
- Grand Prix: complete 3 laps before every other driver.
- Time Trial: there is no opponent — beating your best lap is winning.
- Endless Cruise: there is no finish line — the run ends at 3 crashes
  (or when the player ends it); distance is the score.

## 10. Draw conditions
No draws. Places are assigned by checkpoint progress, which is a strict
ordering; ties are broken by distance to the next checkpoint.

## 11. AI strategy
AI drivers steer toward a lookahead checkpoint (further ahead for higher
levels), with turn rates 2.4 / 3.0 / 3.6 rad/s and base top speeds
238 / 264 / 286, scaled by difficulty (Easy ×0.90, Medium ×1.0,
Hard ×1.07). AI occasionally drift-boosts out of corners and rubber-bands
to the leader. AI never leaves the road deliberately and never collides
with other cars on purpose (no car-car collision in this game).

## 12. Edge cases
- A human who never steers still accelerates and finishes — slowly.
- If the app is backgrounded mid-race, the race auto-pauses.
- The physics timer is engine-owned; a watchdog re-arms it if it ever
  stops, so a race can never freeze in an unfinishable state.
- Restart from pause rebuilds the race identically (new random track
  seed).

## 13. Test cases
- Start a Grand Prix: countdown 3-2-1-GO plays, engine sound starts.
- Drag: car steers; hard drag at speed charges drift meter, full meter
  fires boost with sound + flames.
- Leave the road: car slows; in Endless, 0.6s off-road at speed crashes
  (spin + sound + shake), 3 crashes ends the run.
- Complete 3 laps: results screen shows full standings, best lap
  recorded, win/lose sound.
- Pause mid-race: engine freezes; resume continues; restart resets.
- Background the app mid-race: race pauses, music pauses, both resume.
- Rename drivers, pick Pro-locked theme while free: locked (no crash),
  unlocks after Pro purchase.
- Store unconfigured: Pro screen shows "available after store setup",
  no fake buy buttons.

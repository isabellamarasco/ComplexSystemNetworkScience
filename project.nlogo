globals [
  my-turtles
  payoff-matrix
  clust-coeff
]

turtles-own
[
  infected?           ;; if true, the agent is infectious, role feature
  exposed?            ;; if true, the agent is exposed, role feature
  recovered?          ;; if true, the agent is recovered, role feature
  healthy?
  virus-recovered-period   ;; number of ticks since this agent's last virus check
  strategy
  payoff
  my-clustering-coefficient   ; the current clustering coefficient of this node
]

to setup
  clear-all
  random-seed 42
  create-turtles population
  let payoffs [[1 0][0 1]]
  set payoff-matrix payoffs
  set-population
  reset-ticks
end

to set-population
   ask turtles [
    set shape "person"
    setxy random-xcor random-ycor
    healthy
    if infection = true [
      set virus-recovered-period random virus-check-frequency
    ]
    if game-theory = true [
      set payoff 0
      set strategy 0
    ]
  ]
  layout-circle turtles 10
end

to virus-initialization
  if infection = true [
    ask turtles [healthy]
    ask n-of initial-infected turtles [infect]
  ]
end

to go
  ifelse infection = true [
    if ( ticks >= max-ticks )[stop]
    ask turtles
    [
      set virus-recovered-period virus-recovered-period + 1
      if virus-recovered-period >= virus-check-frequency[
        set virus-recovered-period 0
    ]]
  interaction-between-agents
  do-virus-checks
  tick
  ][stop]

end

;; Erdÿos-Ŕenyi with probability
to build-network
  ask links [ die ]
  ask turtles [
    ask turtles with [ who > [ who ] of myself ] [
      if random-float 1.0 < p [
        create-link-with myself
      ]]
    repeat 1 [do-layout]
  ]
  tick
end

to add-friendship
  ask one-of turtles [
    create-link-with one-of other turtles with [ not in-link-neighbor? turtle who ]
  ]
end


;; Classic Erdős-Rényi random network.
to go-random
  ask links [ die ]
  if num-links > max-links [ set num-links max-links ]
  while [ count links < num-links ] [
    ask one-of turtles [
      create-link-with one-of other turtles
    ]
  ]
 repeat 1 [ do-layout ]
  tick
end

to-report max-links
  report min (list (population * (population - 1) / 2) 50000)
end

; Game theory
to go-game
   ifelse game-theory = true[
    if (ticks >= max-ticks )[stop]
    ask turtles [start-play]
    ask turtles[update-strategy]
    tick
  ][stop]

end

to start-play
  if (game-theory = true)[
    ifelse (count-links >= popular) [
      set strategy 1
    ][set strategy 0]
  ]
end

to update-strategy
  let another-turtle one-of other turtles
  ;;selezioniamo un altro giocatore contro il quale giocare
    if item ([strategy] of another-turtle) (item strategy payoff-matrix) = 1 [
    ifelse infection = false [
       if random-float 1 < add-friendship-p[
      add-friendship
  ]][create-link-with one-of other turtles with [not infected?]]]
end


;; Infection diffusion model
to interaction-between-agents
  ask turtles with [infected?][
      if count my-links > 0[
      ask link-neighbors[
          if not recovered? and random-float 100 < exposed-chance[
          expose
    ]]]]
end

to do-virus-checks
  ask turtles with [(infected? and virus-recovered-period = 0) or exposed? and virus-recovered-period = 0][
    if random 100 < recovery-chance[
      recover]]
  ask turtles with [exposed?][
     if random-float 100 < virus-spread-chance[
      infect
  ]]
end

to expose
  set infected? false
  set exposed? true
  set recovered? false
  set healthy? false
  set virus-recovered-period random virus-check-frequency
  set color orange

end

to infect
  set infected? true
  set exposed? false
  set recovered? false
  set healthy? false
  set color red
end

to healthy
  set infected? false
  set exposed? false
  set recovered? false
  set healthy? true
  set color green
end

to recover
  set infected? false
  set exposed? false
  set recovered? true
  set healthy? false
  set color [0 100 0]
end


to do-layout
  layout-spring turtles with [ any? link-neighbors ] links 0.4 6 1
  display
  display
end

; delete or add frienship with whoever
to update-network
  if ticks >= max-ticks [stop]
  ifelse random-float 1 < drop-friendship-p[
    delete-links
  ][add-friendship]
  display
  tick
end

to delete-links
  if count links > 0 [
    ask one-of links [ die ]
  ]
end

;;add or delete links with infected turtles
to go-modify-network
  ifelse infection = true[
  if ticks >= max-ticks [stop]
  ifelse random-float 1 < add-friendship-p[
   add-link-good
  ][delete-infected-links]][stop]

end

;; add friendship with good reputation
to add-link-good
    ask turtles [
    if count-links > 0 [
        if (count turtles with [not infected?] != nobody)[
        create-link-with one-of other turtles with [not infected?]
  ]]]
 tick
end

to-report count-links
  report count my-links
end

to-report max-popular
  ifelse count links > 0[
  report max [ count my-links] of turtles
  ] [report 0]
end

;; delete friendship with infected people
to delete-infected-links
  if ticks >= max-ticks [stop]
  if count links > 0 [
    ask turtles with [infected?][
      ask my-links [
        die
  ]]]
tick
end


;;Metrics
to-report average-friends
  ifelse count links > 0 [
    report mean [count out-link-neighbors] of turtles
  ][report 0]
end

to-report average-friends-of-friends
  ifelse count links > 0 [
    report sum [((count out-link-neighbors) ^ 2 )] of turtles / sum [(count out-link-neighbors)] of turtles
  ][report 0]
end

to-report clustering-coefficient
  ifelse all? turtles [ count link-neighbors <= 1 ] [
    ; it is undefined
    ; what should this be?
    set clust-coeff 0
  ][
    let total 0
    ask turtles with [ count link-neighbors <= 1 ] [ set my-clustering-coefficient "undefined" ]
    ask turtles with [ count link-neighbors > 1 ] [
      let hood link-neighbors
      set my-clustering-coefficient (2 * count links with [ in-neighborhood? hood ] /
                                         ((count hood) * (count hood - 1)) )
      ; find the sum for the value at turtles
      set total total + my-clustering-coefficient
    ]
    ; take the average
    set clust-coeff total / count turtles with [count link-neighbors > 1]
  ]
  report clust-coeff
end

to-report in-neighborhood? [ hood ]
  report ( member? end1 hood and member? end2 hood )
end
@#$#@#$#@
GRAPHICS-WINDOW
633
10
1070
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
109
59
508
93
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
6
14
106
47
population
population
0
300
200.0
1
1
NIL
HORIZONTAL

BUTTON
175
109
270
142
build-network
build-network
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
44
109
162
142
p
p
0
1
0.3
0.1
1
NIL
HORIZONTAL

BUTTON
525
108
602
141
NIL
go-random
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
114
14
243
47
initial-infected
initial-infected
0
population - 1
120.0
1
1
NIL
HORIZONTAL

MONITOR
1079
272
1139
317
Infected
count turtles with [infected?]
3
1
11

SLIDER
136
419
311
452
drop-friendship-p
drop-friendship-p
0
1
1.0
0.1
1
NIL
HORIZONTAL

BUTTON
338
420
524
453
update-network-random
update-network
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
185
178
218
virus-check-frequency
virus-check-frequency
0
10
5.0
1
1
ticks
HORIZONTAL

SLIDER
190
184
347
217
virus-spread-chance
virus-spread-chance
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
498
183
622
216
recovery-chance
recovery-chance
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
354
183
490
216
exposed-chance
exposed-chance
0
1
0.2
0.1
1
NIL
HORIZONTAL

BUTTON
338
233
611
267
diffusion infection
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
55
233
309
267
NIL
virus-initialization
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
1078
10
1516
263
Status-virus
Time
% Population
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"healthy" 1.0 0 -14439633 true "" "plot (count turtles with [not infected? and not recovered? and not exposed?]) / (count turtles) * 100"
"infected" 1.0 0 -5298144 true "" "plot(count turtles with [infected?]) / (count turtles) * 100"
"recovered" 1.0 0 -13210332 true "" "plot(count turtles with [recovered?]) / (count turtles) * 100"
"exposed" 1.0 0 -955883 true "" "plot(count turtles with [exposed?])/(count turtles) * 100"

MONITOR
886
493
1050
538
average-friends
average-friends
5
1
11

MONITOR
885
546
1051
591
average-friends-of-friends
average-friends-of-friends
5
1
11

MONITOR
1152
271
1222
316
Recovered
count turtles with [recovered?]
17
1
11

MONITOR
1236
271
1302
316
Exposed
count turtles with [exposed?]
17
1
11

BUTTON
197
275
482
309
add or delete infected links
go-modify-network
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
276
161
309
add-friendship-p
add-friendship-p
0
1
0.3
0.1
1
NIL
HORIZONTAL

MONITOR
1206
326
1272
371
num links
count links
17
1
11

MONITOR
1315
270
1380
315
Healthy
count turtles with [not infected? and not recovered? and not exposed?]
17
1
11

MONITOR
885
597
1010
642
clustering coefficient
clustering-coefficient
2
1
11

MONITOR
1080
327
1189
372
link more popular
max-popular
10
1
11

SLIDER
377
108
512
141
num-links
num-links
0
max-links
13876.0
1
1
NIL
HORIZONTAL

SWITCH
495
14
620
47
game-theory
game-theory
1
1
-1000

SWITCH
379
14
490
47
infection
infection
1
1
-1000

PLOT
1077
384
1566
677
Strategy Game Theory Distribution
Time
# Population
0.0
10.0
0.0
10.0
true
true
"clear-plot\nset-plot-y-range 0 population" "set-plot-x-range 0 max list 1 ticks\n\n"
PENS
"No popular" 1.0 0 -6917194 true "" "plot count turtles with [strategy = 0]"
"Popular" 1.0 0 -8990512 true "" "plot count turtles with [strategy = 1]"

BUTTON
333
344
521
378
NIL
go-game
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
438
463
876
779
AVG_f Vs AVG_ff
Time
#Population
0.0
10.0
0.0
10.0
true
true
"clear-plot\nset-plot-y-range 0 population" "set-plot-x-range 0 max list 1 ticks"
PENS
"AVG_f" 1.0 0 -14730904 true "" "plot average-friends"
"AVG_ff" 1.0 0 -4699768 true "" "plot average-friends-of-friends"

MONITOR
884
648
1021
693
Diff AVG_ff and AVG_f
average-friends-of-friends - average-friends
5
1
11

SLIDER
137
344
310
377
popular
popular
0
max-popular
67.0
1
1
NIL
HORIZONTAL

SLIDER
253
14
371
47
max-ticks
max-ticks
0
2000
1000.0
1
1
NIL
HORIZONTAL

TEXTBOX
248
160
437
180
Diffusion infection model
13
0.0
1

TEXTBOX
279
316
446
342
Game Theory
13
0.0
1

TEXTBOX
276
389
443
409
Both Models
13
0.0
1

TEXTBOX
12
751
208
807
Isabella Marasco - 1040993\nisabella.marasco3@studio.unibo.it
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

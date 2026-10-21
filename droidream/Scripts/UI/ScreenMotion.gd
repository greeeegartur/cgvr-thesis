extends RefCounted
class_name ScreenMotion

# Timing shared by the screens between encounters (rewards, boon selection, shop): the same dim, stagger and exit rules, so they feel like one family

const DIM_TIME := 0.7 # The world dims and lights up again over this time
const ENTER_TIME := 0.52 # One element popping in
const EXIT_TIME := 0.3 # One element leaving, about 60% of entering
const STAGGER := 0.12 # Gap between neighbors that appear one after the other
const EXIT_STAGGER := 0.06
const DROP_PIXELS := 10.0 # How far elements sink while they leave
const HP_FADE_TIME := 0.25 # The Droid's HP icon leaves and returns on this

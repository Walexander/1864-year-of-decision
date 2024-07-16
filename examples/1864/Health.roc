module [ range, new ]
# Health := [ Living { hp: U32 }, Dead ]
# new : U32 -> Health
# new = \hp ->
#     tag =
#         if hp <= 0 then
#             Dead { frameOfDeath: U32 }
#         else
#             Living { hp }
#     @Health tag

# hitPoints : Health -> [Living U32, Dead]
# hitPoints = \@Health component ->
#     when component is
#         Dead -> Dead
#         Living { hp } -> Living hp

# expect
#     hp = 25
#     actual = new hp
#     (hitPoints actual) == Living hp

# expect
#     actual = hitPoints (new 0)
#     actual == Dead


CombatStats : {
    type: [Infantry, Artillery, Cavalry],
    entity: I8,
    readiness: [Targeting I8, Defending, Attacking I8, Mustering],
    lastFired: U32,
    rate: U32,
    range: U8,
    damage: U32,
}
Combatant := CombatStats
new = \stats -> @Combatant stats

range : Combatant -> U8
range = \@Combatant stats -> stats.range

fireAway = \@Combatant stats, enemies, frame ->
    Hit { victimId: 3, damage: 25, frame }

testCombatant = Health.new {
    type: Infantry,
    entity: 1,
    readiness: Defending,
    lastFired: 0,
    rate: 200,
    range: 1,
    damage: 25
}

expect
    actual = (range testCombatant)
    actual == 1

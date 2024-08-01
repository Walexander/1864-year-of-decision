module [Unit, MoveChoice, Id, combatOrder, isAlive, takeHit, summary, reroutePath, update, make, moveTo, initial]
import Hex exposing [Doubled, doubled, cubeLerp]
import Utils exposing [frameCountToSeconds]
import Health
import Assets
import w4.Sprite exposing [Sprite]
Id : I8
Unit : {
    id : Id,
    moveRate : F32,
    cooldownRate : F32,
    attackDamage : U32,
    army : [Union, Confederates],
    health : [Living Health.Health, Dead U32],
    position : Hex.Point,
    cell : Doubled,
    dest : Doubled,
    sprite : Sprite,
    lastPath : List Doubled,
    readiness : [Cooldown U32, Ready, Moving],
    range : U8,
}
MoveChoice : [
    Selected Id (List Doubled),
    Destination Id Doubled (List Doubled),
    Finished,
]
make : _ -> Unit
make = \{ type, id: inId, army, cell } ->
    position = Hex.hexToPixel cell
    lastPath = []
    id = Num.toI8 inId
    when type is
        Artillery ->
            {
                id,
                attackDamage: 18u32,
                army,
                position,
                readiness: Ready,
                health: Living (Health.make 125),
                cell,
                dest: cell,
                lastPath,
                moveRate: 120,
                cooldownRate: 60.0 * 4,
                range: 2,
                sprite: Assets.cannon,
            }

        Infantry ->
            {
                id,
                attackDamage: 15u32,
                army,
                position,
                health: Living (Health.make 100),
                readiness: Ready,
                cell,
                dest: cell,
                lastPath,
                moveRate: 90,
                cooldownRate: 60.0 * 3,
                range: 8,
                sprite: Assets.infantry,
            }

        Cavalry ->
            {
                id,
                attackDamage: 11u32,
                army,
                position,
                readiness: Ready,
                health: Living (Health.make 80),
                cell,
                dest: cell,
                lastPath,
                moveRate: 50,
                cooldownRate: 60.0 * 2.125,
                range: 1,
                sprite: Assets.horsey,
            }

moveTo = \unit, dest -> { unit &
        dest,
        readiness: Moving,
        lastPath: cubeLerp unit.cell dest,
    }
isAlive = \{ health } ->
    when health is
        Living hp -> Health.isAlive hp
        Dead _ -> Bool.false

takeHit = \{ health }, damage ->
    when health is
        Living hp -> Health.takeHit hp damage |> Living
        other -> other

combatOrder = \unit, modifier, units ->
    canFire =
        when unit.readiness is
            Ready -> Bool.true
            _ -> Bool.false
    if !(isAlive unit) || !canFire then
        Err NoEnemy
    else
        getTargeting units unit
        |> Result.map \target ->
            attack = Num.toF32 unit.attackDamage
            mod = Num.toF32 modifier |> Num.div 100f32 |> Num.add 1f32
            damage =
                (mod)
                |> Num.mul (attack / 2)
                |> Num.round
                |> Num.toU32
            (unit, target, damage)

getTargeting = \units, unit ->
    Hex.neighborsOf unit.cell
    |> List.joinMap \cell ->
        List.findFirst units \u ->
            when u.health is
                Living _ -> u.cell == cell && u.army != unit.army
                Dead _ -> Bool.false
        |> Result.map \u -> [u]
        |> Result.withDefault []
    |> List.first
    |> Result.mapErr \_ -> NoEnemies

expect
    health = Living (Health.make 100)
    for = { army: Confederates, cell: doubled 2 2, health }
    units = [
        { army: Union, cell: doubled 2 4, health },
        { army: Union, cell: doubled 3 3, health },
        for,
    ]
    actual =
        getTargeting units for
        |> Result.map \{ health: h } ->
            when h is
                Living hp -> Health.health hp
                Dead _ -> 0
    expected =
        List.first units
        |> Result.map \{ health: h } ->
            when h is
                Living hp -> Health.health hp
                Dead _ -> 0
    actual == expected

initial : List Unit
initial = [
    Unit.make { id: 5, type: Cavalry, army: Union, cell: doubled 1 1 },
    Unit.make { id: 4, type: Infantry, army: Union, cell: doubled 1 5 },
    Unit.make { id: 3, type: Infantry, army: Union, cell: doubled 0 4 },
    Unit.make { id: 6, type: Artillery, army: Confederates, cell: doubled 10 6 }
    |> Unit.moveTo (doubled 6 2),
    Unit.make { id: 7, type: Cavalry, army: Confederates, cell: doubled 12 8 }
    |> Unit.moveTo (doubled 5 1),
    Unit.make { id: 8, type: Infantry, army: Confederates, cell: doubled 12 0 }
    |> Unit.moveTo (doubled 4 10),
]

update : Unit, U64, MoveChoice, (Doubled -> Bool) -> Unit
update = \original, frameCount, move, cannotMoveTo ->
    { cell, dest, moveRate } = original
    (newDest, newPath) = unitPathFromMove original move cannotMoveTo
    moveCountDown = frameCount % (Num.round moveRate)
    marchingOrder =
        when newPath is
            [] -> Stopped
            [_] if moveCountDown == 0 -> Stopped
            [nextCell] -> DoneMoving nextCell
            [nextCell, destination] if cannotMoveTo destination -> DoneMoving nextCell
            [_, nextCell, ..] if cannotMoveTo nextCell ->
                UpdatePathTo newDest newPath

            [from, next, ..] -> ProceedTo from next newDest newPath

    when marchingOrder is
        Stopped ->
            readiness =
                when original.readiness is
                    Cooldown countdown if countdown > 0 -> Cooldown (countdown - 1)
                    Cooldown _ -> Ready
                    Moving -> Cooldown (original.cooldownRate |> Num.round)
                    other -> other
            { original & readiness, lastPath: [] }

        DoneMoving finalDestination ->
            position =
                Hex.pointLerp
                    (Hex.hexToPixel original.cell)
                    (Hex.hexToPixel finalDestination)
                    (
                        moveCountDown
                        |> Num.toFrac
                        |> Num.div moveRate
                    )
            { original & position, lastPath: [] }

        ProceedTo _ nextCell destination _ if moveCountDown == 0 ->
            { original &
                cell: nextCell,
                position: Hex.hexToPixel nextCell,
                readiness: Moving,
                dest: destination,
            }

        ProceedTo fromCell nextCell destination path ->
            position =
                Hex.pointLerp
                    (Hex.hexToPixel fromCell)
                    (Hex.hexToPixel nextCell)
                    (
                        moveCountDown
                        |> Num.toFrac
                        |> Num.div moveRate
                    )
            { original &
                dest: destination,
                readiness: Moving,
                lastPath: path,
                cell: fromCell,
                position: position,
            }

        UpdatePathTo destination nextPath ->
            lastPath =
                Hex.findGraph cell dest cannotMoveTo
                |> Result.onErr \_ ->
                    Hex.closestNeighbors cell dest
                    |> List.dropIf \neighbor -> cannotMoveTo neighbor
                    |> List.first
                    |> Result.try \aDest -> Hex.findGraph cell aDest cannotMoveTo
                |> Result.onErr \_ -> Hex.findGraph cell (doubled 1 1) cannotMoveTo
                |> Result.withDefault (List.dropLast nextPath 1)
            { original &
                dest: List.last lastPath |> Result.withDefault destination,
                lastPath,
            }

unitPathFromMove = \unit, move, isblocked ->
    when move is
        Destination id chosen _ if id == unit.id ->
            if isblocked chosen then
                (unit.cell, unit.lastPath)
            else
                path =
                    Hex.findGraph unit.cell chosen isblocked
                    |> Result.map \p -> reroutePath p unit.lastPath unit.cell
                    |> Result.withDefault []
                (chosen, path)

        _ -> (unit.dest, unit.lastPath)

summary = \unit, planned ->
    id = unit.id
    next =
        List.get unit.lastPath 1
        |> Result.map \n -> "$(Num.toStr n.column),$(Num.toStr n.row)"
        |> Result.withDefault "none"

    readyState =
        when unit.readiness is
            Cooldown ticked ->
                tickSeconds =
                    ticked
                    |> frameCountToSeconds
                    |> Num.mul 10
                    |> Num.round
                    |> Num.toFrac
                    |> Num.div 10
                    |> Num.toStr
                "C<$(tickSeconds)>"

            Moving -> "M"
            Ready -> "R"

    health =
        when unit.health is
            Living hp ->
                Health.health hp
                |> Num.mul 100
                |> Num.round
                |> Num.toFrac
                |> Num.div 100
                |> Num.toStr

            Dead time -> "Dead since $(time |> Num.toStr)"
    unitPos = "$(Num.toStr unit.position.x),$(Num.toStr unit.position.y)"
    distance = "$(Hex.hexDistance unit.cell unit.dest |> Num.toStr)]/$(List.len unit.lastPath |> Num.toStr)"
    """
    #$(Num.toStr id)/H:$(health)
    $(Num.toStr unit.cell.column),$(Num.toStr unit.cell.row)->$(next) $(unitPos)
    dest:$(Num.toStr unit.dest.column),$(Num.toStr unit.dest.row) $(distance)
    [$(List.len unit.lastPath |> Num.toStr):$(List.len planned |> Num.toStr)] {$(readyState)}
    """

reroutePath = \newPath, lastPath, currentCell ->
    lastNextStep =
        List.get lastPath 1
        |> Result.map Moving
        |> Result.withDefault (StandingStill currentCell)

    newNextStep =
        List.get newPath 1
        |> Result.map Moving
        |> Result.withDefault (NotMoving currentCell)

    when (lastNextStep, newNextStep) is
        (Moving prevCell, Moving nextCell) if prevCell == nextCell -> newPath
        (Moving prevCell, Moving _) ->
            List.concat [currentCell, prevCell] newPath

        (_, _) -> newPath

## reroutePath should no op when paths are the same
expect
    last = [Hex.doubled 0 0, Hex.doubled 0 2]
    next = [Hex.doubled 0 0, Hex.doubled 0 2]
    actual = reroutePath next last (Hex.doubled 0 0)
    actual == next

## reroutePath returns new path when next step is same in both
expect
    last = [Hex.doubled 0 0, Hex.doubled 0 2]
    next = [Hex.doubled 0 0, Hex.doubled 0 2, Hex.doubled 0 4]
    actual = reroutePath next last (Hex.doubled 0 0)
    actual == next
## reroutePath prefixes current and next cell onto path when different
expect
    last = [Hex.doubled 0 0, Hex.doubled 0 2]
    next = [Hex.doubled 0 0, Hex.doubled 2 0, Hex.doubled 4 0]
    actual = reroutePath next last (Hex.doubled 0 0)
    expected = [
        Hex.doubled 0 0,
        Hex.doubled 0 2,
        Hex.doubled 0 0,
        Hex.doubled 2 0,
        Hex.doubled 4 0,
    ]
    actual == expected


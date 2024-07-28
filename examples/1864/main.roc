app [main, Model] {
    w4: platform "../../platform/main.roc",
}
import w4.Task exposing [Task]
import w4.W4
import w4.Sprite exposing [Sprite]
import Assets
import Hex exposing [Doubled, doubled]

import Drawing
import Health

UnitId : I8
MoveChoice : [
    Selected UnitId (List Doubled),
    Destination UnitId Doubled (List Doubled),
    Finished,
]

Army : [Union, Confederates]

armyColor = \army ->
    when army is
        Union -> Color2
        Confederates -> Color3

armyName = \army ->
    when army is
        Union -> "Union"
        Confederates -> "Confederacy"

armyPalette = \army ->
    when army is
        Union -> unionPalette
        Confederates -> confederatePalette

playerArmy = \player ->
    when player is
        Player1 | Player3 -> Union
        Player2 | Player4 -> Confederates
Palette : {
    color1 : U32,
    color2 : U32,
    color3 : U32,
    color4 : U32,
}
ScreenState : [
    TitleScreen TitleState,
    InGame GameState,
    GameOver GameOverState,
]

YearOfDecision : {
    frameCount : U64,
    inputs : (W4.Gamepad, W4.Gamepad),
    lastInputs : (W4.Gamepad, W4.Gamepad),
    palettes : (Palette, Palette, Palette),
    palette : Palette,
    # background: Sprite,
    # backgrounds: List Sprite,
    screenState : ScreenState,
}
Model : YearOfDecision
TitleState : {
    ready : [
        WaitingBoth,
        Ready [Union, Confederates],
        BothReady,
    ],
}
GameOverState : {
    winner : [Union, Confederates],
    restartIn : U32,
    elapsed : U64,
}

LaunchPad : List Doubled
LaunchPads : List LaunchPad
Map : {
    obstacles : List Doubled,
    launchPads : LaunchPads,
}
GameState : {
    map : Map,
    startFrame : U64,
    launchTimer : U16,
    units : List Unit,
    armies : (Army, Army),
    launchIn : U16,
    hovering : {
        union : Doubled,
        confederate : Doubled,
    },
    unitIndex : {
        union : U64,
        confederate : U64,
    },
    moves : (MoveChoice, MoveChoice),
}

palette = {
    color1: 0xfce4a8,
    color2: 0x71969f,
    color3: 0xd71a21,
    color4: 0x01334e,
}
redPosterPalette = {
    color1: 0xe8d6c0,
    color2: 0x92938d,
    color3: 0xa1281c,
    color4: 0x000000,
}

# redAlert = 0xc4181f
# greenAlert = 0x426e5d
unionPalette = palette
confederatePalette = redPosterPalette
main = { init, update }

isAlive = \health ->
    when health is
        Living hp -> Health.isAlive hp
        Dead _ -> Bool.false

takeHit = \health, damage ->
    when health is
        Living hp -> Health.takeHit hp damage |> Living
        other -> other

initialUnits = [
    makeUnit { id: 5, type: Cavalry, army: Union, cell: doubled 1 1 },
    makeUnit { id: 4, type: Infantry, army: Union, cell: doubled 1 5 },
    makeUnit { id: 3, type: Infantry, army: Union, cell: doubled 0 4 },
    makeUnit { id: 6, type: Artillery, army: Confederates, cell: doubled 10 6 }
    |> moveUnitTo (doubled 6 2),
    makeUnit { id: 7, type: Cavalry, army: Confederates, cell: doubled 12 8 }
    |> moveUnitTo (doubled 5 1),
    makeUnit { id: 8, type: Infantry, army: Confederates, cell: doubled 12 0 }
    |> moveUnitTo (doubled 4 10),
]

defaultGamepad : W4.Gamepad
defaultGamepad = {
    up: Bool.false,
    down: Bool.false,
    left: Bool.false,
    right: Bool.false,
    button1: Bool.false,
    button2: Bool.false,
}

getFirstMove = \forArmy, units ->
    List.findFirst units \{ army } -> army == forArmy
    |> Result.map \{ id } -> Selected id []
    |> Result.withDefault Finished

newGame : U64, Army, Army -> GameState
newGame = \startFrame, player1Army, player2Army ->
    launchIn = 60 * 20
    units = initialUnits # List.dropLast initialUnits 0 # [] #initialUnits
    unionMove = getFirstMove Union initialUnits
    confederateMove = getFirstMove Confederates initialUnits

    {
        startFrame,
        units,
        launchIn,
        unitIndex: {
            union: 1u64,
            confederate: 1u64,
        },
        moves: (unionMove, confederateMove),
        armies: (player1Army, player2Army),
        map: {
            obstacles: [
                doubled 2 4,
                doubled 4 6,
                doubled 8 6,
                doubled 6 4,
                doubled 5 5,
                doubled 7 5,
                doubled 6 6,
                doubled 6 8,
                doubled 5 7,
                doubled 7 7,
                doubled 10 4,
                doubled 2 10,
                doubled 3 11,
            ],
            launchPads: [
                # [
                #     doubled 3 9,
                #     doubled 2 10,
                #     doubled 3 11,
                # ],
                [
                    doubled 5 3,
                    doubled 7 3,
                ],
                [
                    doubled 5 9,
                    doubled 6 10,
                    doubled 7 9,
                ],
            ],
        },
        launchTimer: launchIn,
        hovering: {
            union: doubled 4 0,
            confederate: doubled 8 4,
        },
    }

baseState : Model
baseState = {
    frameCount: Num.toU64 0,
    palette: palette,
    inputs: (defaultGamepad, defaultGamepad),
    lastInputs: (defaultGamepad, defaultGamepad),
    palettes: (palette, unionPalette, confederatePalette),
    screenState: TitleScreen { ready: WaitingBoth },
}

init : Task Model []
init =
    W4.setPalette! palette
    Task.ok baseState

Unit : {
    id : I8,
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

makeUnit = \{ type, id: inId, army, cell } ->
    position = Hex.hexToPixel cell
    lastPath = [] # Hex.findPath cell dest
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

moveUnitTo = \unit, dest -> { unit &
        dest,
        readiness: Moving,
        lastPath: Hex.cubeLerp unit.cell dest,
    }

getPadOwner : List Unit, LaunchPad -> [Owned [Union, Confederates], Unowned]
getPadOwner = \units, pad ->
    byArmy = List.walk pad [] \accum, cell ->
        List.findFirst units \u -> u.cell == cell
        |> Result.map \u -> List.append accum u.army
        |> Result.withDefault accum

    (union, confederates) = List.walk byArmy (0, 0) \accum, army ->
        when army is
            Union -> (accum.0 + 1, accum.1)
            Confederates -> (accum.0, accum.1 + 1)

    if union == confederates then
        Unowned
    else if union > 0 && confederates == 0 then
        Owned Union
    else if confederates > 0 && union == 0 then
        Owned Confederates
    else
        Unowned

countPadsByOwner = \owners ->
    List.walk owners (0, 0) \accum, owner ->
        when owner is
            Owned Union -> (accum.0 + 1, accum.1)
            Owned Confederates -> (accum.0, accum.1 + 1)
            Unowned -> accum

getLaunchStatus = \owners ->
    (union, confederates) = countPadsByOwner owners
    if union > confederates then
        InControl Union
    else if confederates > union then
        InControl Confederates
    else
        StaleMate

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

updateUnit : Unit, U64, MoveChoice, (Doubled -> Bool) -> Unit
updateUnit = \original, frameCount, move, cannotMoveTo ->
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

isCellOccupied : List Unit, List Doubled -> (Doubled -> Bool)
isCellOccupied = \units, obstacles ->
    occupied = List.map units \u -> u.cell
    \cell ->
        List.contains occupied cell
        || List.contains obstacles cell

update : Model -> Task Model []
update = \model ->
    inputs = getPlayerInputs!
    netplay = W4.getNetplay!

    screenState =
        when model.screenState is
            TitleScreen state ->
                renderTitleScreen state model.frameCount
                |> Task.await \_ -> updateTitle state inputs model.inputs model.frameCount

            GameOver state ->
                renderGameOver state model.frameCount
                |> Task.await \_ -> updateGameOver state model.frameCount

            InGame state ->
                renderInGame state netplay model.frameCount
                |> Task.await \_ -> updateInGame state model.frameCount inputs model.inputs

    updated = updateFrameCount
        { model &
            inputs,
            lastInputs: model.inputs,
        } # |> updateBackground
    Task.await screenState \ss ->
        Drawing.drawTitle boardRect
        |> Task.map \_ -> { updated & screenState: ss }

updateFrameCount = \prev ->
    frameCount = Num.addWrap prev.frameCount 1
    { prev & frameCount }

# getCurrentPlayer : _ -> [Player1, Player2]
getCurrentPlayer = \netplay ->
    when netplay is
        Enabled p -> p
        _ -> Player1

getPlayerInputs =
    p1 = W4.getGamepad! Player1
    p2 = W4.getGamepad! Player2
    Task.ok (p1, p2)

padFor = \string, size ->
    strLen = Str.countUtf8Bytes string
    diff = (size - strLen)
    if diff <= 0 then
        ""
    else
        List.repeat " " diff
        |> Str.joinWith ""

leftPad = \string, size ->
    padFor string size
    |> Str.concat string

rightPad = \string, size ->
    Str.concat string (padFor string size)

## Should left pad
expect
    actual = leftPad "123" 5
    expected = "  123"
    actual == expected
expect
    actual = rightPad "123" 5
    expected = "123  "
    actual == expected

expect
    actual = Health.new {
        type: Infantry,
        entity: 1,
        readiness: Defending,
        lastFired: 0,
        rate: 200,
        range: 1,
        damage: 25,
    }
    (Health.range actual) == 1

updateTitle = \state, inputs, lastInputs, frameCount ->
    netplay = W4.getNetplay!
    thePlayer = getCurrentPlayer netplay
    army = playerArmy thePlayer
    W4.setPalette! (armyPalette army)
    pressed = {
        union: inputs.0.button1 && !lastInputs.0.button1,
        confederates: inputs.1.button1 && !lastInputs.1.button1,
    }

    ready =
        when state.ready is
            Ready forAction ->
                when forAction is
                    Union if pressed.confederates -> BothReady
                    Confederates if pressed.union -> BothReady
                    _ -> Ready forAction

            WaitingBoth if pressed.union -> Ready Union
            WaitingBoth if pressed.confederates -> Ready Confederates
            WaitingBoth | BothReady -> state.ready
    newState =
        when ready is
            BothReady -> InGame (newGame frameCount Union Confederates)
            # BothReady -> GameOver { restartIn: 5, winner: Union, elapsed: frameCount }
            _ -> TitleScreen { state & ready }
    Task.ok newState

updateGameOver = \state, frameCount ->
    { restartIn } = state
    elapsedSeconds = frameCountToSeconds state.elapsed |> Num.round # Num.toFrac elapsed |> Num.div 60.0 |> Num.round # |> Num.toStr
    elapsedSince = frameCountToSeconds frameCount |> Num.round # |> Num.div 60.0 |> Num.round
    sinceOver = (elapsedSince - elapsedSeconds)
    next = if sinceOver >= restartIn then baseState.screenState else GameOver state
    Task.ok next

renderTitleScreen : TitleState, U64 -> _
renderTitleScreen = \state, frameCount ->
    netplay = W4.getNetplay!
    thePlayer = getCurrentPlayer netplay
    army = playerArmy thePlayer
    textX = boardRect.x + 10
    halfY =
        boardRect.height
        |> Num.toFrac
        |> Num.div 2
        |> Num.sub 5
        |> Num.round

    elapsedSeconds =
        frameCount
        |> frameCountToSeconds
        |> Num.round
        |> Num.toStr
    Drawing.drawGameTime! elapsedSeconds
    readyMessage =
        when state.ready is
            WaitingBoth -> "Press \u(81) to begin"
            Ready readyArmy if readyArmy == army -> "...Waiting on..."
            Ready _ -> "Press \u(81) already!"
            BothReady -> "Let's roc"
    title = armyName army
    help =
        """
        Timer ticks when
        either army
        controls the
        launch pads.
        """
    disclaimer =
        """
        Be in control
        when the timer
        hits 0 to win!
        """
    W4.setTextColors! { bg: Color4, fg: None }
    gameName = " 1864! "
    gameName |> W4.text! { x: textX, y: boardRect.y }
    W4.setTextColors! { fg: Color2, bg: None }
    " $(title) " |> W4.text! { x: textX, y: boardRect.y + 10 }
    W4.setTextColors! { bg: Color2, fg: Color3 }
    " $(readyMessage) " |> W4.text! { x: textX - 12, y: halfY + 10 }
    W4.setTextColors! { fg: Color4, bg: None }
    help |> W4.text! { x: 15, y: halfY + 25 }
    W4.setTextColors! { fg: Color3, bg: None }
    disclaimer |> W4.text { x: 15, y: halfY + 65 }

renderGameOver = \state, frameCount ->
    restartIn = 5
    { winner } = state
    color = armyColor winner
    name = armyName winner
    netplay = W4.getNetplay!
    thePlayer = getCurrentPlayer netplay
    theArmy = playerArmy thePlayer

    elapsed = Num.toFrac state.elapsed |> Num.div 60.0 |> Num.round # |> Num.toStr
    elapsedSince = Num.toFrac frameCount |> Num.div 60.0 |> Num.round
    # W4.debug! "Elapsed" elapsed
    sinceOver = (elapsedSince - elapsed)

    playerPalette = W4.getPalette!
    W4.setPalette! playerPalette
    W4.rect! { width: 140, height: 80, x: 10, y: 30 }
    W4.setShapeColors! { border: color, fill: color }
    W4.rect! { width: 138, height: 25, x: 11, y: 31 }
    W4.setTextColors! { fg: Color4, bg: None }
    outcome =
        if theArmy == winner then
            "WIN"
        else
            "LOSE"
    "You $(outcome)!!" |> W4.text! { x: 17, y: 35 }
    message =
        """
        After $(Num.toStr elapsed)
        long seconds,the
        $(name) Army
        wins.
        """
    message |> W4.text! { x: 17, y: 60 }

    countDown = restartIn - sinceOver
    restartMessage = " Restart in $(Num.toStr countDown) "
    size =
        Str.countUtf8Bytes restartMessage
        |> Num.toFrac
        |> Num.div 2
        |> Num.mul 8
        |> Num.round
    W4.setTextColors! { fg: Color1, bg: Color2 }
    restartMessage |> W4.text! { x: Num.abs (80 - size), y: 100 }

getUnitFromClickedCell = \units, selected, army ->
    List.findFirst units \u -> u.cell == selected && u.army == army && isAlive u.health

basePoint : Hex.Point
basePoint = { x: 5, y: 20 }

boardRect = {
    x: basePoint.x |> Num.toI32,
    y: basePoint.y |> Num.toI32,
    width: Num.toU32 150,
    height: Num.toU32 100,
}
frameCountToSeconds = \x -> Num.toFrac x |> Num.div 60

getHoverCell = \hoverCell, gamePad, lastGamepad ->
    hoverCell
    |> \{ row, column } ->
        if gamePad.up && Bool.not lastGamepad.up then
            { row: row - 2, column }
        else
            { row, column }
    |> \{ row, column } ->
        if gamePad.down && Bool.not lastGamepad.down then
            { row: row + 2, column }
        else
            { row, column }
    |> \{ row, column } ->
        if gamePad.left && Bool.not lastGamepad.left then
            { row: row + 1, column: column - 1 }
        else
            { row, column }
    |> \{ row, column } ->
        if gamePad.right && Bool.not lastGamepad.right then
            { row: row + 1, column: column + 1 }
        else
            { row, column }

makeUnitIdLocator = \units -> \queryId -> List.findFirst units \{ id } -> id == queryId
makeUnitIdIndexer = \units -> \queryId -> List.findFirstIndex units \{ id } -> id == queryId

updateInGame = \model, frameCount, inputs, lastInputs ->
    padOwners = List.map model.map.launchPads \pad ->
        getPadOwner model.units pad
    launchStatus = getLaunchStatus padOwners
    launchTimer =
        if model.launchTimer <= 0 then
            model.launchTimer
        else
            when launchStatus is
                InControl _ -> Num.sub model.launchTimer 1
                StaleMate -> model.launchTimer

    isOccupied = isCellOccupied model.units model.map.obstacles
    (unionInputs, confedInputs) =
        when model.armies is
            (Union, Confederates) ->
                ({ inputs: inputs.0, last: lastInputs.0 }, { inputs: inputs.1, last: lastInputs.1 })

            _ -> ({ inputs: inputs.1, last: lastInputs.1 }, { inputs: inputs.0, last: lastInputs.0 })

    pressed = {
        union: unionInputs.inputs.button1 && !unionInputs.last.button1,
        confederates: confedInputs.inputs.button1 && !confedInputs.last.button1,
    }
    pressedZ = {
        union: unionInputs.inputs.button2 && !unionInputs.last.button2,
        confederates: confedInputs.inputs.button2 && !confedInputs.last.button2,
    }
    getUnitById = makeUnitIdLocator model.units

    unionHoverCell =
        getHoverCell model.hovering.union unionInputs.inputs unionInputs.last
        |> Hex.clamp

    (unionMove, nextUnionIndex) =
        updateMoveChoice model.moves.0 {
            isOccupied,
            getUnitById,
            wasPressed: pressed.union,
            zPressed: pressedZ.union,
            nextIndex: model.unitIndex.union,
            hovering: unionHoverCell,
            theArmy: Union,
            units: List.keepIf model.units \u -> u.army == Union,
        }

    confedHover =
        getHoverCell model.hovering.confederate confedInputs.inputs confedInputs.last
        |> Hex.clamp
    (confedMove, nextConfedIndex) =
        updateMoveChoice model.moves.1 {
            isOccupied,
            getUnitById,
            wasPressed: pressed.confederates,
            zPressed: pressedZ.confederates,
            nextIndex: model.unitIndex.confederate,
            hovering: confedHover,
            theArmy: Confederates,
            units: List.keepIf model.units \u -> u.army == Confederates,
        }

    units = List.walk model.units [] \accum, u ->
        unitUpdate =
            when u.army is
                Union -> updateUnit u frameCount unionMove isOccupied
                Confederates -> updateUnit u frameCount confedMove isOccupied

        List.append
            accum
            { unitUpdate & position: unitUpdate.position }

    combatModifiers = randList! { length: List.len units }
    combatUnits =
        if frameCount % 6 == 0 then
            runCombat units combatModifiers
            |> List.keepIf \{ health } -> isAlive health
        else
            units
    nextState =
        if launchTimer > 0 then
            InGame
                { model &
                    moves: (unionMove, confedMove),
                    hovering: {
                        union: maybeUpdateHoverCell isOccupied model.unitIndex.union nextUnionIndex unionHoverCell,
                        confederate: maybeUpdateHoverCell isOccupied model.unitIndex.confederate nextConfedIndex confedHover,
                    },
                    unitIndex: {
                        union: nextUnionIndex,
                        confederate: nextConfedIndex,
                    },
                    launchTimer,
                    units: combatUnits,
                }
        else
            when launchStatus is
                InControl winner ->
                    GameOver { winner, restartIn: 5, elapsed: frameCount }

                StaleMate -> crash "launch timer should not tick without winner"
    Task.ok nextState

maybeUpdateHoverCell = \isOccupied, oldIndex, newIndex, current ->
    if oldIndex != newIndex then
        Hex.neighborsOf current
        |> List.dropIf \c -> isOccupied c
        |> List.first
        |> Result.withDefault current
    else
        current

renderInGame = \model, netplay, _frameCount ->
    thePlayer = getCurrentPlayer netplay
    theArmy = playerArmy thePlayer
    getUnitById = makeUnitIdLocator model.units
    totalMs =
        model.launchIn
        |> frameCountToSeconds
        |> Num.mul 1000
        |> Num.round
    msRemaining =
        model.launchTimer
        |> frameCountToSeconds
        |> Num.mul 1000
        |> Num.round

    (theMove, theHoverCell) =
        if theArmy == Union then
            (model.moves.0, model.hovering.union)
        else
            (model.moves.1, model.hovering.confederate)

    drawObs = List.walk model.map.obstacles (Task.ok {}) \task, obs ->
        task!
        { x, y } = Hex.hexToPixel obs
        W4.setShapeColors! { border: Color4, fill: None }
        Drawing.blitHexagon! obs boardRect Assets.filledHex
        W4.setTextColors { fg: Color1, bg: None }
        |> Task.await \_ -> W4.text "@" { x: x + boardRect.x + 4, y: boardRect.y + y + 2 }
    Drawing.drawBoardRect! boardRect
    drawObs!

    getOwner = \pad -> getPadOwner model.units pad
    Drawing.drawPads! model.map.launchPads getOwner
    Drawing.drawLaunchTimer! msRemaining totalMs
    Drawing.drawPlayerMove! model.moves.0 getUnitById Color2
    Drawing.drawPlayerMove! model.moves.1 getUnitById Color3
    W4.setShapeColors! {border: armyColor Union, fill: None }
    Drawing.drawHoverPositon! model.hovering.union
    W4.setShapeColors! {border: armyColor Confederates, fill: None }
    Drawing.drawHoverPositon! model.hovering.confederate

    selectedUnit =
        when theMove is
            Selected id _ | Destination id _ _ ->
                getUnitById id
                |> Result.map \unit -> Chosen unit
                |> Result.withDefault None
            _ -> None

    _ <-
        List.keepIf model.units \u -> isAlive u.health
        |> \units -> Drawing.drawUnits units boardRect # isSelected theArmy
        |> Task.await

    task =
        when selectedUnit is
            Chosen u -> Drawing.drawSelectionIndicator (u.position) (armyColor u.army)
            None -> Task.ok {}
    task!
    unitSummary =
        when theMove is
            Selected id path | Destination id _ path ->
                getUnitById id
                |> Result.map \unit -> getUnitSummary unit path
                |> Result.withDefault "He dead ..."

            Finished -> ""

    shapeColors = { fill: Color1, border: Color4 }
    W4.setShapeColors! shapeColors
    infoY = boardRect.y + (Num.toI32 boardRect.height)
    W4.rect! {
        x: 0,
        y: infoY,
        height: Num.toU32 (160 - (boardRect.y + (Num.toI32 boardRect.height))),
        width: 160,
    }
    W4.setTextColors! { fg: Color4, bg: None }
    W4.text! unitSummary {
        x: boardRect.x,
        y: infoY + 2,
    }
    W4.setTextColors! { bg: Color4, fg: None }
    currCellText = " $(Num.toStr theHoverCell.column),$(Num.toStr theHoverCell.row) "
    width = Str.countUtf8Bytes currCellText
    W4.text! currCellText {
        x: boardRect.x + (Num.toI32 boardRect.width) - (Num.toI32 (width * 7)),
        y: (boardRect.y + (Num.toI32 boardRect.height) + 2) |> Num.abs,
    }
    Drawing.resetColors

updateMoveChoice : MoveChoice, _ -> (MoveChoice, U64)
updateMoveChoice = \currentChoice, { hovering, theArmy, getUnitById, zPressed, wasPressed, nextIndex, isOccupied, units } ->
    selected = getUnitFromClickedCell units hovering theArmy
    total = List.len units
    idx = if total > 0 then nextIndex % total else 0
    (resultChoice, newIndex) =
        when currentChoice is
            Destination _ _ _ | _ if zPressed ->
                List.get units idx
                |> Result.map \u -> (Selected u.id u.lastPath, idx + 1)
                |> Result.withDefault (currentChoice, nextIndex)

            Destination _ _ _ ->
                List.get units idx
                |> Result.map \u -> (Selected u.id u.lastPath, idx + 1)
                |> Result.withDefault (currentChoice, nextIndex)

            Finished if wasPressed ->
                units
                |> List.findFirst \{ cell, army } -> cell == hovering && army == theArmy
                |> Result.map \u -> (Selected u.id [], nextIndex)
                |> Result.withDefault (Finished, nextIndex)

            Selected id path if wasPressed ->
                getUnitById id
                |> Result.map \u ->
                    if u.cell == hovering then
                        (Finished, nextIndex)
                    else if isOccupied hovering then
                        selected
                        |> Result.map \newUnit -> (Selected newUnit.id newUnit.lastPath, nextIndex)
                        |> Result.withDefault (Finished, nextIndex)
                    else
                        (Destination u.id hovering path, nextIndex)
                |> Result.withDefault (currentChoice, nextIndex)

            Selected id prevPath ->
                destUpdated =
                    List.last prevPath
                    |> Result.map \prevDest -> prevDest != hovering
                    |> Result.withDefault Bool.true
                unitMoved =
                    List.first prevPath
                    |> Result.try \last ->
                        getUnitById id
                        |> Result.map \u -> u.cell != last
                    |> Result.withDefault Bool.true
                if unitMoved || destUpdated then
                    (updatePlayerPlannedPath id hovering prevPath getUnitById isOccupied, nextIndex)
                else
                    (Selected id prevPath, nextIndex)

            otherwise -> (otherwise, nextIndex)

    (resultChoice, newIndex)

updatePlayerPlannedPath = \id, hovering, prevPath, getUnitById, isOccupied ->
    getUnitById id
    |> Result.map \u ->
        withoutMe = \cell ->
            if u.cell == cell then
                Bool.false
            else
                isOccupied cell
        if withoutMe hovering then
            prevPath
        else
            Hex.findGraph u.cell hovering withoutMe
            |> Result.map \p ->
                when u.readiness is
                    Moving ->
                        reroutePath p u.lastPath u.cell

                    _ -> p
            |> Result.withDefault prevPath
    |> Result.map \newPath -> Selected id newPath
    |> Result.withDefault Finished

getUnitSummary = \unit, planned ->
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

getCombatOrders = \unitsAndModifiers ->
    justUnits = List.map unitsAndModifiers .0
    List.keepOks unitsAndModifiers \(u, modifier) ->
        canFire =
            when u.readiness is
                Ready -> Bool.true
                _ -> Bool.false
        if isAlive u.health && canFire then
            getTargeting justUnits u
            |> Result.map \target ->
                attack = Num.toF32 u.attackDamage
                mod = Num.toF32 modifier |> Num.div 100f32 |> Num.add 1f32
                damage =
                    (mod)
                    |> Num.mul (attack / 2)
                    |> Num.round
                    |> Num.toU32
                (u, target, damage)
        else
            Err NoEnemy

randList = \{ length } ->
    List.range { start: At 0, end: At length }
    |> List.walk (Task.ok []) \last, _ ->
        last
        |> Task.await \accum ->
            W4.randBetween { start: 1, before: 100 }
            |> Task.map \mod -> List.append accum mod

runCombat = \units, modifiers ->
    indexer = makeUnitIdIndexer units
    # First get all of the eligible attackers
    # and their single target
    combatOrders =
        List.map2 units modifiers \u, m -> (u, m)
        |> getCombatOrders

    # Now walk over the list of (attacker, defender, damage) triples
    # and accumulate an updated list of units
    List.walk combatOrders units \accum, (source, target, damage) ->
        # Update `readinesss` of attacking unit
        updatedAccum =
            List.findFirstIndex accum \u -> u.id == source.id
            |> Result.map \attackerIdx ->
                List.update accum attackerIdx \u ->
                    { u & readiness: Cooldown (Num.round u.cooldownRate) }
            |> Result.withDefault accum
        ## Update `health` of defender
        indexer target.id
        |> Result.map \victimIndex ->
            List.update updatedAccum victimIndex \u ->
                #           ^^--- update the new version
                { u & health: takeHit u.health damage }
        |> Result.withDefault updatedAccum

## runCombat should get targets, update health
expect
    testUnits = [
        {
            id: 0,
            cooldownRate: 100.0,
            readiness: Ready,
            army: Union,
            cell: doubled 2 4,
            health: Living (Health.make 200),
            attackDamage: 5u32,
        },
        {
            id: 1,
            cooldownRate: 50.0,
            readiness: Ready,
            army: Confederates,
            cell: doubled 3 3,
            health: Living (Health.make 100),
            attackDamage: 10u32,
        },
    ]

    actual =
        runCombat testUnits [100, 100]
        |> List.map \{ health } ->
            when health is
                Living h -> Health.health h
                _ -> 0

    expectedLessThan = List.map testUnits \u ->
        when u.health is
            Living h -> Health.health h
            _ -> 0

    List.all
        (List.map2 actual expectedLessThan (\a, e -> a <= e))
        \r -> r == Bool.true

## runCombat should not over/underflow
expect
    testUnits = [
        {
            id: 0,
            cooldownRate: 100.0,
            readiness: Ready,
            army: Union,
            cell: doubled 2 4,
            health: Living (Health.make 9),
            attackDamage: 10u32,
        },
        {
            id: 1,
            cooldownRate: 100.0,
            readiness: Ready,
            army: Confederates,
            cell: doubled 3 3,
            health: Living (Health.make 100),
            attackDamage: 10u32,
        },
    ]
    actual = runCombat testUnits [100, 100] |> List.map \{ health } -> isAlive health
    expected = [Bool.false, Bool.true]
    actual == expected

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

# updateBackground : Model -> Model
# updateBackground = \gameState ->
#     {
#         gameState &
#         background:
#             when gameState.screenState is
#                 TitleScreen _ -> getArt gameState
#                 InGame _ -> getArt gameState
#                 GameOver { winner } ->
#                     when winner is
#                         Union -> Assets.dawn
#                         Confederates -> Assets.flame
#     }

# getArt : Model -> Sprite
# getArt = \model ->
#     if model.frameCount % 301 != 0 then
#         model.background
#     else
#         totalBackgrounds = List.len model.backgrounds
#         (Num.toU32 model.frameCount) % (Num.toU32 totalBackgrounds)
#         |> \index -> List.get model.backgrounds (Num.toU64 index)
#             |> Result.withDefault model.background

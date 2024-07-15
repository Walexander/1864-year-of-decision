app [main, Model] {
    w4: platform "../../platform/main.roc",
}

import w4.Task exposing [Task]
import w4.W4
import w4.Sprite exposing [Sprite]
import Assets
import Hex exposing [Doubled, hexWidth, hexHeight, doubled, drawHex, lerp]

UnitId : I8
MoveChoice : [
    Selected UnitId,
    Destination (UnitId, Doubled), Finished]
LaunchPad : List Doubled
LaunchPads : List LaunchPad

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
    color1: U32,
    color2: U32,
    color3: U32,
    color4: U32,
}
ScreenState : [
        TitleScreen TitleState,
        InGame GameState,
        GameOver GameOverState
    ]

YearOfDecision : {
    frameCount: U64,
    inputs: (W4.Gamepad, W4.Gamepad),
    lastInputs: (W4.Gamepad, W4.Gamepad),
    palettes: (Palette, Palette, Palette),
    palette: Palette,
    background: Sprite,
    backgrounds: List Sprite,
    screenState: ScreenState,
}
Model : YearOfDecision
TitleState : {
    ready: [WaitingBoth, Ready [Union, Confederates], BothReady]
}
GameOverState : {
    winner: [Union, Confederates],
    elapsed: U32,
}
GameState : {
    obstacles: List Doubled,
    launchTimer : U16,
    units : List Unit,
    launchIn : U16,
    launchPads : LaunchPads,
    hovering: {
        union: Doubled,
        confederate: Doubled,
    },
    moves : {
        union: MoveChoice,
        confederate: MoveChoice
    }
}

palette = {
    # color1: 0xf6c6a8,
    # color2: 0x5b768d,
    # color3: 0xd17c7c,
    # color4: 0x46425e,
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

redAlert = 0xc4181f
greenAlert = 0x426e5d
# redPalette = {
#     color1: 0xf6c6a8,
#     color2: 0x5b768d,
#     color3: 0xd17c7c,
#     color4: redAlert,
# }
unionPalette = palette
confederatePalette = redPosterPalette
# {
#     # color1: 0xfafbf6,
#     # color2: 0x565a75,
#     # color3: 0xc6b7be,
#     # color4: 0x0f0f1b,
#     color1: 0xf6c6a8,
#     color2: 0x5b768d,
#     color3: 0xd17c7c,
#     color4: 0x46425e,
# }
main = { init, update }
initialUnits =
    unit1 = {
        id: 0,
        position: Hex.hexToPixel (doubled 0 0),
        moveRate: 120,
        lastPath: [],
        army: Union,
        cell: doubled 0 0,
        dest: doubled 9 1,
        sprite: Assets.infantry,
    }
    dest2 = doubled 3 3
    start2 = doubled 1 1
    unit2 : Unit
    unit2 = {
        id: 1,
        army: Union,
        moveRate: 60,
        lastPath: Hex.findPath start2 dest2,
        position: Hex.hexToPixel (start2),
        cell: start2,
        dest: dest2,
        sprite: Assets.horsey,
    }
    unitDest = doubled 8 10
    unit3 : Unit
    unit3 = {
        id: 2,
        moveRate: 150,
        army: Confederates,
        lastPath: Hex.findPath (doubled 11 1) unitDest,
        position: Hex.hexToPixel (doubled 11 1),
        cell: doubled 11 1,
        dest: unitDest,
        sprite: Assets.cannon,
    }
    unit4 = {
        id: 3,
        moveRate: 30,
        army: Confederates,
        lastPath: [],
        position: Hex.hexToPixel (doubled 9 3),
        cell: doubled 9 3,
        dest: doubled 9 3,
        sprite: Assets.horsey
    }
    [unit1, unit2, unit3, unit4]

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
    |> Result.map \{id} -> Selected id
    |> Result.withDefault Finished

newGame : GameState
newGame =
    launchIn = 60 * 1 * 20
    units = initialUnits
    unionMove = getFirstMove Union initialUnits
    confederateMove = getFirstMove Confederates initialUnits
    {
        units,
        launchIn,
        moves: {
            union: unionMove,
            confederate: confederateMove,
        },
        obstacles: [
            # doubled 5 3, doubled 6 4,doubled 7 3,
            doubled 5 5, doubled 6 6,doubled 7 5,
            doubled 5 7, doubled 6 8,doubled 7 7,
        ],
        launchTimer: launchIn,
        hovering : {
            union: (doubled 4 0),
            confederate: (doubled 8 4),
        },
        launchPads: [
            [
                doubled 4 8,
                doubled 5 9,
                doubled 4 10,
            ],
            [
                doubled 5 3,
                doubled 6 2,
                doubled 7 3,
            ],
            [
                doubled 7 9,
                doubled 8 10,
                doubled 8 8,
            ],
        ],
    }

baseState : Model
baseState = {
    background: Assets.flame,
    backgrounds: [ Assets.velvet, Assets.bloodMoon, Assets.dawn, Assets.flame ],
    frameCount: Num.toU64 0,
    palette: palette,
    inputs: (defaultGamepad, defaultGamepad),
    lastInputs: (defaultGamepad, defaultGamepad),
    palettes: (palette, unionPalette, confederatePalette),
    screenState: TitleScreen { ready: WaitingBoth }
}

init : Task Model []
init =
    W4.setPalette! palette
    Task.ok baseState

Point : { x : I16, y : I16 }

Unit : { id : I8, moveRate: F32, army : [Union, Confederates], position : Point, cell : Doubled, dest : Doubled, sprite : Sprite, lastPath: List Doubled }

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

unitPathFromMove = \unit, move, isblocked ->
    when move is
        Destination (id, chosen) if id == unit.id ->
            if isblocked chosen then (unit.cell, [])
            else (chosen, (Hex.findGraph unit.cell chosen isblocked |> Result.withDefault []))
        _ -> (unit.dest, unit.lastPath)

updateUnit : Unit, U64, MoveChoice, (Doubled -> Bool) -> Unit
updateUnit = \original, frameCount, move, cannotMoveTo ->
    { cell, dest, moveRate } = original
    (newDest, newPath) = unitPathFromMove original move cannotMoveTo
    path = newPath
    if dest == cell then
        { original & lastPath: path, dest: newDest }
    else
        newCell =
            List.get path 1
            |> Result.map \c -> if (cannotMoveTo c) then cell else c
            |> Result.withDefault cell
        destPoint = Hex.hexToPixel newCell
        moveCountDown = frameCount % (Num.round moveRate)

        if moveCountDown == 0 then
            { original & cell: newCell, lastPath: (List.dropFirst path 1), position: destPoint, dest: newDest }
        else
            sourceCell = Hex.hexToPixel cell
            progress = moveCountDown |> Num.toFrac |> Num.div moveRate
            x = lerp (Num.toI32 sourceCell.x) (Num.toI32 destPoint.x) progress
            y = lerp (Num.toI32 sourceCell.y) (Num.toI32 destPoint.y) progress
            {
                original & cell,
                lastPath: path,
                position: { x: Num.floor x, y: Num.floor y },
                dest: newDest
            }
isCellOccupied : List Unit, List Doubled -> (Doubled -> Bool)
isCellOccupied = \units, obstacles -> \cell ->
    List.any units \unit -> unit.cell == cell
    || List.contains obstacles cell


update : Model -> Task Model []
update = \model ->
    drawTitle! basePoint
    inputs = getPlayerInputs!
    screenState =
        when model.screenState is
            GameOver state ->
                updateGameOver state model.frameCount
            TitleScreen state ->
                updateTitle state inputs model.inputs model.frameCount
            InGame state ->
                updateInGame state model.frameCount inputs model.inputs
    # drawBottomImage! model.background
    updated = updateFrameCount {
        model &
        inputs,
        lastInputs: model.inputs
    } |> updateBackground

    task =
        when model.screenState is
            GameOver _ | InGame _ -> drawBottomImage updated.background
            TitleScreen _ -> Task.ok {}

    task!
    Task.map screenState \ss ->
        { updated & screenState: ss }

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
    dbg string
    dbg strLen
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

updateTitle = \state, inputs, lastInputs, frameCount ->
    netplay = W4.getNetplay!
    thePlayer = getCurrentPlayer netplay
    army = playerArmy thePlayer
    W4.setPalette! (armyPalette army)

    pressed = {
        union: inputs.0.button1 && !lastInputs.0.button1,
        confederates: inputs.1.button1 && !lastInputs.1.button1,
    }


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
    W4.setShapeColors! { fill: Color4, border: Color4 }
    offsetX : I32
    offsetX = 32
    W4.oval! {
        x: 160 - offsetX - 5,
        y: boardRect.y - 5,
        width: 20,
        height: 20
    }


    W4.setTextColors! { fg: Color1, bg: None }
    size = Str.countUtf8Bytes elapsedSeconds
    minusX = Num.toI32 (size - 1) * 2
    elapsedSeconds |> W4.text! {
        x: 160 - offsetX - minusX ,
        y: (boardRect.y + 2)
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
    readyMessage =
        when state.ready is
            WaitingBoth -> "Press \u(81) to begin"
            Ready readyArmy if readyArmy == army -> "  ...Waiting..."
            Ready _ -> "    Press \u(81)\nalready!"
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
    title |> W4.text! { x: textX, y: halfY - 10}
    # title |> W4.text! { x: textX + (7 * 8), y: boardRect.y }
    readyMessage |> W4.text! { x: textX, y: halfY + 10}

    W4.setTextColors! { fg: Color4, bg: None }
    help |> W4.text! { x: 15, y: halfY + 25  }
    W4.setTextColors! { fg: Color3, bg: None }
    disclaimer |> W4.text! { x: 15, y: halfY + 65  }
    newState = when ready is
        BothReady -> InGame newGame
        _ -> TitleScreen { state & ready }
    Task.ok newState


updateGameOver = \state, frameCount ->
    { winner } = state
    color = armyColor winner
    name = armyName winner
    netplay = W4.getNetplay!
    thePlayer = getCurrentPlayer netplay
    theArmy = playerArmy thePlayer
    elapsed = Num.toFrac state.elapsed |> Num.div 60.0 |> Num.round # |> Num.toStr
    elapsedSince = Num.toFrac frameCount |> Num.div 60.0 |> Num.round
    sinceOver = (elapsedSince - elapsed)

    playerPalette = W4.getPalette!
    winnerPalette =
        if winner == theArmy then
            { playerPalette & color2: greenAlert }
        else
            { playerPalette & color2: redAlert }
    W4.setPalette! winnerPalette
    # W4.setShapeColors! { border: Color4, fill: Color1 }
    W4.rect! { width: 140, height: 80, x: 10, y: 30 }

    W4.setShapeColors! { border: color, fill: color }
    W4.rect! { width: 138, height: 25, x: 11, y: 31 }

    W4.setTextColors! { fg: Color1, bg: None }
    outcome =
        if theArmy == winner then "WIN"
        else "LOSE"
    "You $(outcome)!!" |> W4.text! { x: 17, y: 35 }
    W4.setTextColors! { fg: Color4, bg: None }
    message =
        """
        After $(Num.toStr elapsed)
        long seconds,the
        $(name) Army
        wins.
        """
    message |> W4.text! { x: 17, y: 60 }
    W4.setTextColors! { fg: Color1, bg: Color3 }
    "  Restart in $(Num.toStr (5 - sinceOver)) " |> W4.text! {x: 12, y: 100 }
    (sprite, colors) = when winner is
        Union -> (Assets.dawn,  { primary: Color4, secondary: Color2, tertiary: Color3, quaternary: Color1 } )
        Confederates -> (Assets.flame, { primary: Color1, secondary: Color2, tertiary: Color3, quaternary: Color4 })

    W4.setDrawColors!  colors
    Sprite.blit! sprite { x: 0, y: 120 }

    next = if sinceOver > 5 then baseState.screenState else GameOver state
    Task.ok next

getUnitFromClickedCell = \units, selected, army ->
    List.findFirst units \u -> u.cell == selected && u.army == army

# unitFromClick = \units, selected, army, choice ->
#     List.findFirst units \u ->
#         u.cell == selected && u.army == army
#     |> Result.map \u ->
#         when choice is
#             Finished -> (Selected u.id)
#             Selected id ->
#                 if u.id == id then
#                     Finished
#                 else
#                     (Selected u.id)

#             _ -> Err {}
basePoint : Point
basePoint = { x: 0, y: 22 }

boardRect = {
    x: basePoint.x |> Num.toI32,
    y: basePoint.y |> Num.toI32 |> Num.add 2,
    width: 160,
    height: 102
}
frameCountToSeconds = \x -> Num.toFrac x |> Num.div 60

updateBackground : Model -> Model
updateBackground = \gameState ->
    {
        gameState &
        background:
            when gameState.screenState is
                TitleScreen _ -> getArt gameState
                InGame _ -> getArt gameState
                GameOver { winner } ->
                    when winner is
                        Union -> Assets.dawn
                        Confederates -> Assets.flame
    }

getArt : Model -> Sprite
getArt = \model ->
    if model.frameCount % 301 != 0 then
        model.background
    else
        totalBackgrounds = List.len model.backgrounds
        (Num.toU32 model.frameCount) % (Num.toU32 totalBackgrounds)
        |> \index -> List.get model.backgrounds (Num.toU64 index)
            |> Result.withDefault model.background

getHoverCell = \hoverCell, gamePad, lastGamepad ->
    hoverCell
    |> \{row, column} ->
      if gamePad.up && Bool.not lastGamepad.up then { row: row - 2, column }
      else { row, column }
    |> \{row, column} ->
      if gamePad.down && Bool.not lastGamepad.down then { row: row + 2, column }
      else { row, column }
    |> \{row, column} ->
      if gamePad.left && Bool.not lastGamepad.left then { row: row + 1, column: column - 1}
      else { row, column }
    |> \{row, column} ->
      if gamePad.right && Bool.not lastGamepad.right then { row: row + 1, column: column + 1}
      else { row, column }

printPixel = \{x, y}, frameCount, msg ->
    pixel = W4.getPixel! { x, y }
    if frameCount % 300 == 0 then W4.debug msg pixel else Task.ok {}


updateInGame = \model, frameCount, inputs, lastInputs ->
    netplay = W4.getNetplay!

    padOwners = List.map model.launchPads \pad ->
        getPadOwner model.units pad

    isNetplay = when netplay is
        Disabled -> Bool.false
        Enabled _ -> Bool.true

    thePlayer = getCurrentPlayer netplay
    theArmy = playerArmy thePlayer
    playerPalette = armyPalette theArmy
    launchStatus = getLaunchStatus padOwners
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
    percentLeft =
        msRemaining
        |> Num.toFrac
        |> Num.div (Num.toFrac totalMs)

    isRedAlert =
        msRemaining
        |> Num.rem 1000
        |> Num.toFrac
        |> Num.div 1000
        |> \fractionSecond -> fractionSecond > percentLeft


    launchTimer =
        if model.launchTimer <= 0 then
            model.launchTimer
        else
            when launchStatus is
                InControl _ -> Num.sub model.launchTimer 1
                StaleMate -> model.launchTimer


    isOccupied = isCellOccupied model.units model.obstacles
    pressed = {
        union: inputs.0.button1 && !lastInputs.0.button1,
        confederates: inputs.1.button1 && !lastInputs.1.button1,
    }
    getUnitById = \id -> List.get model.units (Num.toU64 id)

    unionHoverCell = getHoverCell model.hovering.union inputs.0 lastInputs.0
    unionMove =
        updateMoveChoice model.moves.union {
            isOccupied,
            wasPressed: pressed.union,
            hovering: unionHoverCell,
            theArmy: Union,
            units: model.units,
        }

    confedHover = getHoverCell model.hovering.confederate inputs.1 lastInputs.1
    confedMove =
        updateMoveChoice model.moves.confederate {
            isOccupied,
            wasPressed: pressed.confederates,
            hovering: confedHover,
            theArmy: Confederates,
            units: model.units,
        }

    units = List.map model.units \u ->
        when u.army is
            Union -> updateUnit u frameCount unionMove isOccupied
            Confederates -> updateUnit u frameCount confedMove isOccupied

#     launchStateColor =
#         when launchStatus is
#             InControl player -> armyColor player
#             StaleMate -> Color4

    colors =
        if msRemaining <= 15000 then
            when launchStatus is
                InControl winning if isRedAlert ->
                    if winning == theArmy then
                        { playerPalette & color4: greenAlert }
                    else
                        { playerPalette & color4: redAlert }
                _ -> playerPalette
        else
            playerPalette

    W4.setPalette! colors
    # W4.setShapeColors! { border: Color4, fill: Color1 }
    # W4.rect! boardRect

    # W4.setShapeColors! { border: Color4, fill: None }
    # drawGrid! model.obstacles Assets.filledHex basePoint

    # Task.loop model.launchPads \pads ->
    #     when pads is
    #         [next, ..rest] ->

    drawPads = List.walk model.launchPads (Task.ok {}) \task, launchPad ->
        task!
        drawLaunchPad launchPad (getPadOwner model.units launchPad) Assets.hex

    drawLaunchTimer! msRemaining totalMs

    drawPads!

    drawUnionMove =
        W4.setPrimaryColor! Color2
        drawPlayerMove! unionMove unionHoverCell getUnitById Color2 isOccupied
        W4.setTextColors! { bg: Color2, fg: None }
        W4.text! "$(Num.toStr unionHoverCell.column),$(Num.toStr unionHoverCell.row)"
            {x: boardRect.x + 4, y: (boardRect.y + boardRect.height - 25) |> Num.abs }
        drawHoverPositon unionHoverCell


    drawConfedMove =
        W4.setPrimaryColor! Color3
        drawPlayerMove! confedMove confedHover getUnitById Color3 isOccupied
        W4.setTextColors! { bg: Color3, fg: None }
        drawHoverPositon confedHover

    # TODO:
    # `drawUnion |> Task.await \_ -> drawConfed`
    # is a compiler error right now
    #
    # drawBoth =
    #     W4.setPrimaryColor! Color2
    #     drawPlayerMove! unionMove unionHoverCell getUnitById Color2 isOccupied
    #     W4.setTextColors! { bg: Color2, fg: None }
    #     drawHoverPositon! unionHoverCell
    #     W4.setPrimaryColor! Color3
    #     drawPlayerMove! confedMove confedHover getUnitById Color3 isOccupied
    #     W4.setTextColors! { bg: Color3, fg: None }
    #     drawHoverPositon confedHover

    effect =
        if isNetplay && theArmy == Union then
            drawUnionMove
        else if isNetplay && theArmy == Confederates then
            drawConfedMove
        else
            # drawBoth!
            drawUnionMove
    effect!
    drawUnits! model.units basePoint model.moves.union

    printPixel! {x: 80, y: 113} frameCount "after"

    state = {
        model &
        moves: {
            union: unionMove,
            confederate: confedMove
        },
        hovering: {
            union: unionHoverCell,
            confederate: confedHover,
        },
        launchTimer, units
    }
    nextState =
        if launchTimer > 0 then
            (InGame state)
        else
            when launchStatus is
                InControl winner ->
                    GameOver { winner, elapsed: Num.toU32 frameCount }
                StaleMate -> crash "launch timer should not tick without winner"
    Task.ok nextState

drawHoverPositon = \cell ->
    point = Hex.hexToPixel cell
    xoffset = Hex.halfWidth |> Num.toFrac |> Num.div 2 |> Num.round
    yoffset = Hex.halfHeight |> Num.toFrac |> Num.div 2 |> Num.round

    width = xoffset * 2 |> Num.toU32
    height = yoffset * 2 |> Num.toU32
    x = point.x |> Num.add (Num.toI16 boardRect.x) |> Num.toI32 |> Num.sub xoffset |> Num.toI32
    y = point.y |> Num.add (Num.toI16 boardRect.y) |> Num.sub (Num.toI16 height) |> Num.toI32
    W4.oval { x, y, height, width}

drawPlayerMove = \move, hovering, get, color, isBlocked ->
    W4.setPrimaryColor! color
    when move is
        Selected id ->
            unit = get id
            destination =
                unit
                |> Result.map .lastPath
                |> Result.withDefault []
            planned =
                if isBlocked hovering then
                    ([])
                else
                    unit
                    |> Result.try \{dest, cell} ->
                        if dest == hovering then Err OutOfBounds
                        else Ok cell
                    |> Result.try \cell ->
                        # Hex.findGraph cell hovering isBlocked
                        Ok (Hex.findPath cell hovering)
                    |> Result.withDefault []
            drawPaths planned destination
        Finished | Destination (_, _) -> Task.ok {}


updateMoveChoice : MoveChoice, _ -> MoveChoice
updateMoveChoice =  \currentChoice, {hovering, theArmy, wasPressed, isOccupied, units} ->
    selected = getUnitFromClickedCell units hovering theArmy
    resultChoice = when currentChoice is
        Destination (unitId, _) -> Ok (Selected unitId)
        Finished if wasPressed ->
            units
            |> List.findFirst \{ cell, army } -> cell == hovering && army == theArmy
            |> Result.map \u -> (Selected u.id)
        Selected id if wasPressed ->
            List.get units (Num.toU64 id)
            |> Result.map \u ->
                if u.cell == hovering then
                    Finished
                else if isOccupied hovering then
                    selected
                    |> Result.map .id
                    |> Result.map Selected
                    |> Result.withDefault (Selected id)
                else
                    Destination (u.id, hovering)
        Finished -> Ok Finished
        Selected id -> Ok (Selected id)
    resultChoice
    |> Result.mapErr \_ -> {}
    |> Result.withDefault currentChoice

drawGrid = \cubes, sprite, point ->
    List.walk cubes (Task.ok {}) \task, cell ->
        task!
        drawHex cell point sprite
resetColors = W4.setDrawColors { primary: Color1, secondary: Color2, tertiary: Color3, quaternary: Color4 }
drawBottomImage = \sprite ->
    W4.setShapeColors! { border: Color4, fill: Color1 }
    W4.rect! {
        x: 0,
        y: 160 - 50,
        width: boardRect.width,
        height: 50,
    }
    sub = Sprite.subOrCrash sprite { srcX: 0, srcY: 0, height: 40, width: 156 }
    resetColors!
    Sprite.blit! sub { x: 2, y: 160 - 45 }

drawPath = \path ->
    List.walkWithIndex path (Task.ok {}) \task, from, i ->
        task!
        List.get path (i + 1)
        |> Result.map \to -> W4.line from to
        |> Result.withDefault (Task.ok {})

drawPaths = \primaryPath, destPath ->
    drawPath! (Hex.pathToLine destPath basePoint)
    _ <-
        List.last destPath
        |> Result.map \cell -> drawHoverPositon cell
        |> Result.withDefault (Task.ok {})
        |> Task.await
    W4.setPrimaryColor! Color4
    drawPath (Hex.pathToLine primaryPath basePoint)

drawUnit = \unit, bp, choice ->
    drawTo = {
        x: (unit.position.x + bp.x - 4) |> Num.toI32,
        y: (unit.position.y + bp.y - 4) |> Num.toI32,
        flags: if unit.army == Confederates then
            [FlipX]
        else
            [],
    }
    border = armyColor unit.army
    fill =
        if unit.army == Confederates then
            Color4
        else
            when choice is
                Selected id -> if unit.id == id then Color4 else None
                _ -> None
    W4.setShapeColors { border, fill }
    |> Task.await \_ -> Sprite.blit unit.sprite drawTo

drawUnits = \units, bp, choice ->
    List.walk units (Task.ok {}) \task, unit ->
        task!
        drawUnit unit bp choice

drawTitle = \point ->
    W4.setShapeColors! { border: Color2, fill: Color4 }
    W4.rect! { height: point.y - 4 |> Num.toU32, width: 160, x: 0, y: 0 }
    W4.setTextColors! { bg: None, fg: Color1 }
    W4.text! " Year of Decision" { x: 10, y: 6 }
    resetColors!

drawLaunchTimer = \remaining, total ->
    totalWidth = hexWidth |> Num.mul 3 |> Num.sub hexWidth |> Num.toFrac

    barX =
        80 - ( totalWidth / 2 )
        |> Num.round
        |> Num.sub Hex.halfWidth
        |> Num.toI32
    barY =
        boardRect.height
        |> Num.toFrac
        |> Num.div 2
        |> Num.round
        |> Num.add hexHeight
        |> Num.add 2
        |> Num.toI32
    windowDims = {
        width: (totalWidth + 10) |> Num.round,
        height: 20,
        x: barX - 5,
        y: (barY - 9) |>Num.abs
    }

    W4.setShapeColors! { border: Color2, fill: Color4 }
    W4.rect! windowDims
    msg =
        if remaining <= 0 then
            ""
        else if remaining < 1_000 then
            remaining
            |> Num.toFrac
            |> Num.div 100
            |> Num.round
            |> Num.toFrac |> Num.div 10 |> Num.toStr |> Str.replaceFirst "0" ""
        else # if remaining < 15_000 then
            remaining |> Num.toFrac |> Num.div 1000 |> Num.round |> Num.toStr
    baseX = 70
    x =
        if Str.countUtf8Bytes msg >= 2 then
            baseX - 5
        else
            baseX
    width =
        (Num.toFrac (total - remaining))
        |> Num.div (Num.toFrac total)
        |> Num.mul totalWidth
        |> Num.round

    W4.setShapeColors! { border: Color2, fill: None }
    W4.rect! { x: barX, y: barY + 4, width: Num.round totalWidth, height: 5 }

    W4.setShapeColors! { border: Color1, fill: Color3 }
    W4.rect! { x: barX, y: barY + 4, width, height: 5 }

    W4.setTextColors! { bg: None, fg: Color1 }
    msg |> W4.text! { x, y: barY - 6 |> Num.abs }

drawLaunchPad = \pad, owner, sprite ->
    color =
        when owner is
            Owned p -> armyColor p
            Unowned -> Color4
    W4.setTextColors! { fg: None, bg: color }
    drawGrid! pad sprite basePoint

app [main, Model] {
    w4: platform "../../platform/main.roc",
}
import w4.Task exposing [Task]
import w4.W4
import w4.Sprite exposing [Sprite]
import Assets
import Hex exposing [Doubled, doubled, lerp]

import Drawing
import Health

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
        Player1 | Player3 -> Confederates
        Player2 | Player4 -> Union
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
unionPalette = palette
confederatePalette = redPosterPalette
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
        range: 1,
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
        range: 1,
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
        range: 2,
        sprite: Assets.cannon,
    }
    unit4 = {
        id: 3,
        moveRate: 30,
        army: Confederates,
        lastPath: Hex.findPath (doubled 12 0) (doubled 0 16),
        position: Hex.hexToPixel (doubled 9 3),
        cell: doubled 12 0,
        dest: doubled 0 16,
        range: 1,
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
    launchIn = 60 * 30
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

Unit : {
    id : I8,
    moveRate: F32,
    army : [Union, Confederates],
    position : Hex.Point,
    cell : Doubled,
    dest : Doubled,
    sprite : Sprite,
    lastPath: List Doubled,
    range: U8,
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

unitPathFromMove = \unit, move, isblocked ->
    when move is
        Destination (id, chosen) if id == unit.id ->
            if isblocked chosen then (unit.cell, unit.lastPath)
            else (chosen, (Hex.findGraph unit.cell chosen isblocked |> Result.withDefault []))
        _ ->
            (unit.dest, unit.lastPath)

updateUnit : Unit, U64, MoveChoice, (Doubled -> Bool) -> Unit
updateUnit = \original, frameCount, move, cannotMoveTo ->
    { cell, dest, moveRate } = original
    (newDest, newPath) = unitPathFromMove original move cannotMoveTo

    if dest == cell then
        { original & lastPath: newPath, dest: newDest }
    else
        (newCell, finalPath) =
            List.get newPath 1
            |> Result.try \c ->
                if !(cannotMoveTo c) then
                    Ok (c, newPath)
                else
                    # we cant move to our next cell
                    # so find a new path
                    Hex.findGraph cell dest cannotMoveTo
                    # and keep our current cell
                    |> Result.map \path -> (cell, path)
            |> Result.withDefault (cell, newPath)

        moveCountDown = frameCount % (Num.round moveRate)
        destPoint = Hex.hexToPixel newCell

        if moveCountDown == 0 then
            {
                original &
                cell: newCell,
                lastPath: (List.dropFirst finalPath 1),
                position: destPoint,
                dest: newDest
            }
        else
            sourceCell = Hex.hexToPixel cell
            progress = moveCountDown |> Num.toFrac |> Num.div moveRate
            x = lerp (Num.toI32 sourceCell.x) (Num.toI32 destPoint.x) progress
            y = lerp (Num.toI32 sourceCell.y) (Num.toI32 destPoint.y) progress
            {
                original &
                lastPath: finalPath,
                position: { x: Num.floor x, y: Num.floor y },
                dest: newDest
            }
isCellOccupied : List Unit, List Doubled -> (Doubled -> Bool)
isCellOccupied = \units, obstacles -> \cell ->
    List.any units \unit -> unit.cell == cell
    || List.contains obstacles cell


update : Model -> Task Model []
update = \model ->
    Drawing.drawTitle! boardRect
    inputs = getPlayerInputs!
    screenState =
        when model.screenState is
            GameOver state ->
                updateGameOver state model.background model.frameCount
            TitleScreen state ->
                updateTitle state inputs model.inputs model.frameCount
            InGame state ->
                updateInGame state model.frameCount inputs model.inputs
    updated = updateFrameCount {
        model &
        inputs,
        lastInputs: model.inputs
    } |> updateBackground

    # task =
    #     when model.screenState is
    #         GameOver _  -> drawBottomImage updated.background
    #         _ -> Task.ok {}

    # task!
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

expect
    actual = Health.new {
        type: Infantry,
        entity: 1,
        readiness: Defending,
        lastFired: 0,
        rate: 200,
        range: 1,
        damage: 25
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
    " $(title) " |> W4.text! { x: textX, y: boardRect.y + 10}
    # title |> W4.text! { x: textX + (7 * 8), y: boardRect.y }
    W4.setTextColors! { bg: Color2, fg: Color3 }
    " $(readyMessage) " |> W4.text! { x: textX - 12, y: halfY + 10}

    W4.setTextColors! { fg: Color4, bg: None }
    help |> W4.text! { x: 15, y: halfY + 25  }
    W4.setTextColors! { fg: Color3, bg: None }
    disclaimer |> W4.text! { x: 15, y: halfY + 65  }
    newState = when ready is
        BothReady -> InGame newGame
        _ -> TitleScreen { state & ready }
    Task.ok newState

updateGameOver = \state, background, frameCount ->
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
            { playerPalette & color3: greenAlert }
        else
            { playerPalette & color3: redAlert }
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

    restartMessage = " Restart in $(Num.toStr (30 - sinceOver)) "
    size = Str.countUtf8Bytes restartMessage
        |> Num.toFrac
        |> Num.div 2
        |> Num.mul 8
        |> Num.round

    W4.setTextColors! { fg: Color1, bg: Color2 }
    restartMessage |> W4.text! {x: Num.abs (80 - size), y: 100 }
    (sprite, colors) = when winner is
        Union ->
            (Assets.dawn,
            { primary: Color4, secondary: Color2, tertiary: Color3, quaternary: Color1 } )
        Confederates ->
            (Assets.flame,
            { primary: Color1, secondary: Color2, tertiary: Color3, quaternary: Color4 })

    W4.setDrawColors!  colors
    Sprite.blit! sprite { x: 0, y: 120 }

    next = if sinceOver > 30 then baseState.screenState else GameOver state
    Drawing.drawBottomImage! background
    Task.ok next

getUnitFromClickedCell = \units, selected, army ->
    List.findFirst units \u -> u.cell == selected && u.army == army

basePoint : Hex.Point
basePoint = { x: 5, y: 20 }

boardRect = {
    x: basePoint.x |> Num.toI32,
    y: basePoint.y |> Num.toI32,
    width: Num.toU32 150,
    height: Num.toU32 100
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
    unionInputs =
        if thePlayer == Player1 && theArmy == Union then
            {inputs: inputs.0, last: lastInputs.0}
        else
            { inputs: inputs.1, last: lastInputs.1 }
    confedInputs =
        if thePlayer == Player1 && theArmy == Union then
            {inputs: inputs.1, last: lastInputs.1}
        else
            { inputs: inputs.0, last: lastInputs.0 }
    pressed = {
        union: unionInputs.inputs.button1 && !unionInputs.last.button1,
        confederates: confedInputs.inputs.button1 && !confedInputs.last.button1
    }
    getUnitById = \id -> List.get model.units (Num.toU64 id)


    unionHoverCell = getHoverCell model.hovering.union unionInputs.inputs unionInputs.last
    unionMove =
        updateMoveChoice model.moves.union {
            isOccupied,
            wasPressed: pressed.union,
            hovering: unionHoverCell,
            theArmy: Union,
            units: model.units,
        }

    confedHover = getHoverCell model.hovering.confederate confedInputs.inputs confedInputs.last
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
    Drawing.drawBoardRect! boardRect

    getOwner = \pad -> getPadOwner model.units pad
    Drawing.drawPads! model.launchPads getOwner
    Drawing.drawLaunchTimer! msRemaining totalMs

    drawUnionMove =
        W4.setPrimaryColor! Color2
        Drawing.drawPlayerMove! unionMove unionHoverCell getUnitById Color2 isOccupied
        W4.setTextColors! { bg: Color2, fg: None }
        W4.text! "$(Num.toStr unionHoverCell.column),$(Num.toStr unionHoverCell.row)"
            {x: boardRect.x + 4, y: (boardRect.y + (Num.toI32 boardRect.height) - 25) |> Num.abs }
        Drawing.drawHoverPositon unionHoverCell


    drawConfedMove =
        W4.setPrimaryColor! Color3
        Drawing.drawPlayerMove! confedMove confedHover getUnitById Color3 isOccupied
        W4.setTextColors! { bg: Color3, fg: None }
        Drawing.drawHoverPositon confedHover

    # TODO:
    # `drawUnion |> Task.await \_ -> drawConfed`
    # is a compiler error right now
    #
    # drawBoth =
    #     W4.setPrimaryColor! Color2
    #     drawPlayerMove! unionMove unionHoverCell getUnitById Color2 isOccupied
    #     W4.setTextColors! { bg: Color2, fg: None }
    #     Drawing.drawHoverPositon! unionHoverCell
    #     W4.setPrimaryColor! Color3
    #     drawPlayerMove! confedMove confedHover getUnitById Color3 isOccupied
    #     W4.setTextColors! { bg: Color3, fg: None }
    #     Drawing.drawHoverPositon confedHover

    effect =
        if theArmy == Union then
            drawUnionMove
        else if theArmy == Confederates then
            drawConfedMove
        else
            # drawBoth!
            drawUnionMove

    effect!
    Drawing.drawUnits! model.units boardRect model.moves.union theArmy

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

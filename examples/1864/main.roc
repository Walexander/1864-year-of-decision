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
    # background: Sprite,
    # backgrounds: List Sprite,
    screenState: ScreenState,
}
Model : YearOfDecision
TitleState : {
    ready: [WaitingBoth,
    Ready [Union, Confederates], BothReady]
}
GameOverState : {
    winner: [Union, Confederates],
    restartIn: U32,
    elapsed: U64,
}

LaunchPad : List Doubled
LaunchPads : List LaunchPad
Map : {
    obstacles: List Doubled,
    launchPads: LaunchPads
}
GameState : {
    map: Map,
    startFrame: U64,
    launchTimer : U16,
    units : List Unit,
    armies: (Army, Army),
    launchIn : U16,
    hovering: {
        union: Doubled,
        confederate: Doubled,
    },
    moves: (MoveChoice, MoveChoice),
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


isAlive = \health ->
    when health is
        Living hp -> Health.isAlive hp
        Dead _ -> Bool.false

takeHit = \health, damage ->
    when health is
        Living hp -> Health.takeHit hp damage |> Living
        other -> other

initialUnits =
    health = Living (Health.make 100)
    unit1: Unit
    unit1 = {
        id: 0,
        position: Hex.hexToPixel (doubled 0 0),
        moveRate: 120,
        health: takeHit health 30,
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
        health,
        lastPath: Hex.findPath start2 dest2,
        position: Hex.hexToPixel (start2),
        cell: start2,
        range: 1,
        dest: dest2,
        sprite: Assets.horsey,
    }
    unitDest = doubled 6 2
    unit3 : Unit
    unit3 = {
        id: 2,
        moveRate: 150,
        health: Living (Health.make 100) |> takeHit 50,
        army: Confederates,
        lastPath: Hex.findPath (doubled 11 1) unitDest,
        position: Hex.hexToPixel (doubled 11 1),
        cell: doubled 11 1,
        dest: unitDest,
        range: 2,
        sprite: Assets.cannon,
    }
    unit4Dest = doubled 5 7
    unit4 = {
        id: 3,
        moveRate: 30,
        army: Confederates,
        lastPath: Hex.findPath (doubled 12 0) unit4Dest,
        position: Hex.hexToPixel (doubled 7 9),
        health: health |> takeHit 20,
        cell: doubled 12 0,
        dest: unit4Dest,
        range: 1,
        sprite: Assets.horsey
    }
    [unit1, unit3, unit2, unit4]

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

newGame : U64, Army, Army -> GameState
newGame = \startFrame, player1Army, player2Army ->
    launchIn = 60 * 15
    units = initialUnits
    unionMove = getFirstMove Union initialUnits
    confederateMove = getFirstMove Confederates initialUnits
    {
        startFrame,
        units,
        launchIn,
        moves: (unionMove, confederateMove) ,
        armies: (player1Army, player2Army),
        map: {
            obstacles: [
                doubled 5 5,            doubled 7 5,
                            doubled 6 6,
                doubled 5 7,             doubled 7 7,
            ],
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
                # [
                #     doubled 7 9,
                #     doubled 8 10,
                #     doubled 8 8,
                # ],
            ],
        },
        launchTimer: launchIn,
        hovering : {
            union: (doubled 4 0),
            confederate: (doubled 8 4),
        },
    }

baseState : Model
baseState = {
    # background: Assets.flame,
    # backgrounds: [ Assets.velvet, Assets.bloodMoon, Assets.dawn, Assets.flame ],
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
    health: [ Living Health.Health, Dead U32 ],
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

shadeRow47 : U8, U8, W4.Palette -> W4.Palette
shadeRow47 = \x, y, c ->
    if y == 46 || y >= 154 then Color1
    else if y == 40 && x > 73 && x < 83 then
        Color1
    else if y != 47 then c
    else
        when c is
            Color1 -> Color4
            Color4 -> Color1
            Color2 -> Color3
            Color3 -> Color2
            None -> Color2

update : Model -> Task Model []
update = \model ->
    inputs = getPlayerInputs!
    Drawing.drawTitle! boardRect
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


    updated = updateFrameCount {
        model &
        inputs,
        lastInputs: model.inputs
    }# |> updateBackground
    Task.map screenState \ss -> { updated & screenState: ss }

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
    newState = when ready is
        BothReady -> InGame (newGame frameCount Union Confederates)
        # BothReady -> GameOver { restartIn: 5, winner: Union, elapsed: frameCount }
        _ -> TitleScreen { state & ready }
    Task.ok newState

updateGameOver = \state, frameCount ->
    { restartIn } = state
    elapsedSeconds = frameCountToSeconds state.elapsed |> Num.round #Num.toFrac elapsed |> Num.div 60.0 |> Num.round # |> Num.toStr
    elapsedSince = frameCountToSeconds frameCount |> Num.round # |> Num.div 60.0 |> Num.round
    sinceOver = (elapsedSince - elapsedSeconds)
    next = if sinceOver >=  restartIn  then baseState.screenState else GameOver state
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
    " $(title) " |> W4.text! { x: textX, y: boardRect.y + 10}
    # title |> W4.text! { x: textX + (7 * 8), y: boardRect.y }
    W4.setTextColors! { bg: Color2, fg: Color3 }
    " $(readyMessage) " |> W4.text! { x: textX - 12, y: halfY + 10}

    W4.setTextColors! { fg: Color4, bg: None }
    help |> W4.text! { x: 15, y: halfY + 25  }
    W4.setTextColors! { fg: Color3, bg: None }
    disclaimer |> W4.text! { x: 15, y: halfY + 65  }

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

    countDown = restartIn - sinceOver
    restartMessage = " Restart in $(Num.toStr countDown) "
    size = Str.countUtf8Bytes restartMessage
        |> Num.toFrac
        |> Num.div 2
        |> Num.mul 8
        |> Num.round

    W4.setTextColors! { fg: Color1, bg: Color2 }
    restartMessage |> W4.text {x: Num.abs (80 - size), y: 100 }

getUnitFromClickedCell = \units, selected, army ->
    List.findFirst units \u -> u.cell == selected && u.army == army && isAlive u.health

basePoint : Hex.Point
basePoint = { x: 5, y: 20 }

boardRect = {
    x: basePoint.x |> Num.toI32,
    y: basePoint.y |> Num.toI32,
    width: Num.toU32 150,
    height: Num.toU32 100
}
frameCountToSeconds = \x -> Num.toFrac x |> Num.div 60

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

# printPixel = \{x, y}, frameCount, msg ->
#     pixel = W4.getPixel! { x, y }
#     if frameCount % 300 == 0 then W4.debug msg pixel else Task.ok {}

makeUnitIdLocator = \units -> \queryId -> List.findFirst units \{id} -> id == queryId
makeUnitIdIndexer = \units -> \queryId -> List.findFirstIndex units \{id} -> id == queryId

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
                ({inputs: inputs.0, last: lastInputs.0}, {inputs: inputs.1, last: lastInputs.1})
            _ -> ({ inputs: inputs.1, last: lastInputs.1 },{inputs: inputs.0, last: lastInputs.0})

    pressed = {
        union: unionInputs.inputs.button1 && !unionInputs.last.button1,
        confederates: confedInputs.inputs.button1 && !confedInputs.last.button1
    }
    getUnitById = makeUnitIdLocator model.units

    unionHoverCell = getHoverCell model.hovering.union unionInputs.inputs unionInputs.last
    unionMove =
        updateMoveChoice model.moves.0 {
            isOccupied,
            getUnitById,
            wasPressed: pressed.union,
            hovering: unionHoverCell,
            theArmy: Union,
            units: model.units,
        }

    confedHover = getHoverCell model.hovering.confederate confedInputs.inputs confedInputs.last
    confedMove =
        updateMoveChoice model.moves.1 {
            isOccupied,
            getUnitById,
            wasPressed: pressed.confederates,
            hovering: confedHover,
            theArmy: Confederates,
            units: model.units,
        }

    units = List.map model.units \u ->
        when u.army is
            Union -> updateUnit u frameCount unionMove isOccupied
            Confederates -> updateUnit u frameCount confedMove isOccupied

    combatUnits =
        if frameCount % 60 == 0 then
            runCombat units
            |> List.keepIf \{health} -> isAlive health
        else
            units
    nextState =
        if launchTimer > 0 then
            (InGame {
                model &
                moves: (unionMove, confedMove),
                hovering: {
                    union: unionHoverCell,
                    confederate: confedHover,
                },
                launchTimer,
                units: combatUnits
            })
        else
            when launchStatus is
                InControl winner ->
                    GameOver { winner, restartIn: 5, elapsed: frameCount }
                StaleMate -> crash "launch timer should not tick without winner"
    Task.ok nextState
#     colors =
#         if msRemaining <= 15000 then
#             when launchStatus is
#                 InControl winning if isRedAlert ->
#                     if winning == theArmy then
#                         { playerPalette & color4: greenAlert }
#                     else
#                         { playerPalette & color4: redAlert }
#                 _ -> playerPalette
#         else
#             playerPalette


#     W4.setPalette! colors
#     Drawing.drawBoardRect! boardRect

#     getOwner = \pad -> getPadOwner model.units pad
#     Drawing.drawPads! model.map.launchPads getOwner
#     Drawing.drawLaunchTimer! msRemaining totalMs

#     # drawUnionMove =
#     W4.setPrimaryColor! Color2
#     Drawing.drawPlayerMove! theMove theHoverCell getUnitById Color2 isOccupied
#     W4.setPrimaryColor! Color3
#     Drawing.drawHoverPositon! theHoverCell
#     List.keepIf combatUnits \u -> isAlive u.health
#     |> Drawing.drawUnits! boardRect theMove theArmy
#     unitSummary = when theMove is
#         Selected id ->
#             getUnitById id
#             |> Result.map \unit ->
#                 health = when unit.health is
#                     Living hp -> Health.health hp |> Num.toStr
#                     Dead time -> "Dead since $(time|>Num.toStr)"
#                 """
#                 id:$(Num.toStr id)
#                 health:$(health)
#                 cell:$(Num.toStr unit.cell.column),$(Num.toStr unit.cell.row)
#                 to:$(Num.toStr theHoverCell.column),$(Num.toStr theHoverCell.row)
#                 """
#             |> Result.withDefault "He dead ..."
#         _ -> ""
#     W4.runShader! shadeRow47
#     W4.setShapeColors! { fill: Color1, border: Color4 }
#     W4.rect! {
#         x: 0,
#         y: boardRect.y  + (Num.toI32 boardRect.height),
#         height: Num.toU32 (160 - (boardRect.y + (Num.toI32 boardRect.height))),
#         width: 160,
#     }

#     W4.setTextColors! { fg: Color4, bg: None }
#     W4.text! unitSummary {
#         x: boardRect.x + 5,
#         y: boardRect.y + (Num.toI32 boardRect.height) + 5,
#     }
#     W4.setTextColors! { bg: Color4, fg: None }
#     W4.text! " $(Num.toStr theHoverCell.column),$(Num.toStr theHoverCell.row) "
#         {x: boardRect.x + (Num.toI32 boardRect.width) - 40,
#         y: (boardRect.y + (Num.toI32 boardRect.height) + 5) |> Num.abs }

renderInGame = \model, netplay, _frameCount ->
    padOwners = List.map model.map.launchPads \pad ->
        getPadOwner model.units pad
    thePlayer = getCurrentPlayer netplay
    theArmy = playerArmy thePlayer
    playerPalette = armyPalette theArmy
    launchStatus = getLaunchStatus padOwners
    getUnitById = makeUnitIdLocator model.units
    isOccupied = isCellOccupied model.units model.map.obstacles
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

    (theMove, theHoverCell) =
        if theArmy == Union then (model.moves.0, model.hovering.union)
        else (model.moves.1, model.hovering.confederate)

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
    Drawing.drawPads! model.map.launchPads getOwner
    Drawing.drawLaunchTimer! msRemaining totalMs

    # drawUnionMove =
    W4.setPrimaryColor! Color2
    Drawing.drawPlayerMove! theMove theHoverCell getUnitById Color2 isOccupied
    W4.setPrimaryColor! Color3
    Drawing.drawHoverPositon! theHoverCell
    List.keepIf model.units \u -> isAlive u.health
    |> Drawing.drawUnits! boardRect theMove theArmy

    unitSummary = when theMove is
        Selected id ->
            getUnitById id
            |> Result.map \unit ->
                health = when unit.health is
                    Living hp -> Health.health hp |> Num.toStr
                    Dead time -> "Dead since $(time|>Num.toStr)"
                """
                id:$(Num.toStr id)
                health:$(health)
                cell:$(Num.toStr unit.cell.column),$(Num.toStr unit.cell.row)
                to:$(Num.toStr theHoverCell.column),$(Num.toStr theHoverCell.row)
                """
            |> Result.withDefault "He dead ..."
        _ -> ""
    W4.runShader! shadeRow47
    W4.setShapeColors! { fill: Color1, border: Color4 }
    W4.rect! {
        x: 0,
        y: boardRect.y  + (Num.toI32 boardRect.height),
        height: Num.toU32 (160 - (boardRect.y + (Num.toI32 boardRect.height))),
        width: 160,
    }

    W4.setTextColors! { fg: Color4, bg: None }
    W4.text! unitSummary {
        x: boardRect.x + 5,
        y: boardRect.y + (Num.toI32 boardRect.height) + 5,
    }
    W4.setTextColors! { bg: Color4, fg: None }
    W4.text! " $(Num.toStr theHoverCell.column),$(Num.toStr theHoverCell.row) "
        {x: boardRect.x + (Num.toI32 boardRect.width) - 40,
        y: (boardRect.y + (Num.toI32 boardRect.height) + 5) |> Num.abs }
    Drawing.resetColors

updateMoveChoice : MoveChoice, _ -> MoveChoice
updateMoveChoice =  \currentChoice, {hovering, theArmy, getUnitById, wasPressed, isOccupied, units} ->
    selected = getUnitFromClickedCell units hovering theArmy
    resultChoice = when currentChoice is
        Destination (unitId, _) -> Ok (Selected unitId)
        Finished if wasPressed ->
            units
            |> List.findFirst \{ cell, army } -> cell == hovering && army == theArmy
            |> Result.map \u -> (Selected u.id)
        Selected id if wasPressed ->
            getUnitById id
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
    |> Result.withDefault Finished

runCombat = \units ->
    indexer = makeUnitIdIndexer units
    List.keepOks units \u ->
        if isAlive u.health then
            getTargeting units u
            |> Result.map \target -> (target, 10) ## <-- u.damage
        else
            Err NoEnemy
    |> List.walk units \accum, (target, damage) ->
        indexer target.id
        |> Result.map \victimIndex ->
            List.update accum victimIndex \u -> { u & health: (takeHit u.health damage) }
        |> Result.withDefault accum

## runCombat should get targets, update health
expect
    testUnits = [
        { id: 0, army: Union, cell: doubled 2 4, health: Living (Health.make 200) },
        { id: 1, army: Confederates, cell: doubled 3 3, health: Living (Health.make 100) },
    ]
    actual = runCombat testUnits |> List.map \{health} ->
        when health is
            Living h -> Health.health h
            _ -> 0
    expected = [ 0.95, 0.9 ]
    actual == expected

## runCombat should not over/underflow
expect
    testUnits = [
        { id: 0, army: Union, cell: doubled 2 4, health: Living (Health.make 9) },
        { id: 1, army: Confederates, cell: doubled 3 3, health: Living (Health.make 100) },
    ]
    actual = runCombat testUnits |> List.map \{health} -> isAlive health
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
        for
    ]
    actual = getTargeting units for |> Result.map \{ health: h } ->
        when h is
            Living hp -> Health.health hp
            Dead _ -> 0
    expected = List.first units |> Result.map \{ health: h } ->
        when h is
            Living hp -> Health.health hp
            Dead _ -> 0
    actual == expected


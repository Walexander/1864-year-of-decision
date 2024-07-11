app [main, Model] {
    w4: platform "../../platform/main.roc",
}

import w4.Task exposing [Task]
import w4.W4
import w4.Sprite exposing [Sprite]
import Assets

MoveChoice : [Selected I8, Destination (Unit, Doubled), Finished]
Player : [Player1, Player2]
LaunchPad : List Doubled
LaunchPads : List LaunchPad

playerColor = \player ->
    when player is
        Player1 -> Color2
        Player2 -> Color3

playerName = \player ->
    when player is
        Player1 -> "Union"
        Player2 -> "Confederacy"

Palette : {
    color1: U32,
    color2: U32,
    color3: U32,
    color4: U32,
}
Model : [
    TitleScreen TitleState,
    InGame GameState,
    GameOver  GameOverState
]
TitleState : U32
GameOverState : {
    frameCount: U32,
    winner: Player,
    palette: Palette,
}
# PlayerState : {
#     hover: Doubled,
#     choice: MoveChoice
# }

palette = {
    color1: 0xf6c6a8,
    color2: 0x5b768d,
    color3: 0xd17c7c,
    color4: 0x46425e,
}

redPalette = {
  # color1: 0xcdc1a7,
  # color2: 0xc4181f,
  # color3: 0x120a19,
  # color4: 0x7e1f23,
    color1: 0xf6c6a8,
    color2: 0x5b768d,
    color3: 0xd17c7c,
    color4: 0xc4181f,
}

player1Palette = {
    color1: 0xcfab51,
    color2: 0x4d222c,
    color3: 0x9d654c,
    color4: 0x210b1b,
}
player2Palette = {
    color1: 0xfafbf6,
    color2: 0x565a75,
    color3: 0xc6b7be,
    color4: 0x0f0f1b,
}
main = { init, update }
initialUnits =
    unit1 = {
        id: 0,
        position: hexToPixel (doubled 1 3),
        moveRate: 30,
        lastPath: [],
        player: Player1,
        cell: doubled 1 3,
        dest: doubled 1 3,
        sprite: Assets.arrow,
    }
    dest2 = doubled 7 3
    start2 = doubled 1 1
    unit2 : Unit
    unit2 = {
        id: 1,
        player: Player1,
        moveRate: 90,
        lastPath: cubeLerp start2 dest2,
        position: hexToPixel (start2),
        cell: start2,
        dest: dest2,
        sprite: Assets.arrow,
    }
    unitDest = doubled 8 10
    unit3 : Unit
    unit3 = {
        id: 2,
        moveRate: 46,
        player: Player2,
        lastPath: cubeLerp (doubled 11 1) unitDest,
        position: hexToPixel (doubled 11 1),
        cell: doubled 11 1,
        dest: unitDest,
        sprite: Assets.arrow,
    }
    [unit1, unit2, unit3]


initialPlayerState =
    p1 = {
        hover: doubled 0 0,
        choice: Finished
    }
    p2 = {
        hover: doubled 12 0,
        choice: Finished
    }
    (p1, p2)


GameState : {
    palettes: (Palette, Palette, Palette),
    obstacles: List Doubled,
    launchTimer : U16,
    launchIn : U16,
    launchPads : LaunchPads,
    p1HoverCell: Doubled,
    moveChoice : MoveChoice,
    background: Sprite,
    backgrounds: List Sprite,
    frameCount : U32,
    lastGamepad: {
        up: Bool,
        down: Bool,
        left: Bool,
        right: Bool,
        button1: Bool,
        button2: Bool,
    },
    units : List Unit,
}


newGame: GameState
newGame =
    launchIn = 900
    units = initialUnits
    player1State = {
        hover: (doubled 0 0),
        choice: Finished,
    }

    {
        palettes: (palette, player1Palette, player2Palette),
        units,
        moveChoice: Selected 0,
        frameCount: Num.toU32 0,
        launchIn: 900,
        obstacles: [],
        launchTimer: launchIn,
        background: Assets.velvet,
        backgrounds: [ Assets.velvet, Assets.bloodMoon, Assets.dawn, Assets.flame ],
        p1HoverCell: (doubled  0 0),
        launchPads: [
            [
                doubled 4 8,
                doubled 5 9,
                doubled 4 10,
            ],
            [
                doubled 7 9,
                doubled 8 10,
                doubled 8 8,
            ],
            [
                doubled 5 3,
                doubled 6 2,
                doubled 7 3,
            ]
        ],
        lastGamepad: {
            up: Bool.false,
            down: Bool.false,
            left: Bool.false,
            right: Bool.false,
            button1: Bool.false,
            button2: Bool.false,
        }
    }
init : Task Model []
init =
    W4.setPalette! player1Palette
    initialState : Model
    initialState = TitleScreen 1
    Task.ok initialState

hexWidth : I16
hexWidth = 12
hexHeight : I16
hexHeight = 6
halfWidth : I16
halfWidth = 6
halfHeight : I16
halfHeight = 3

Point : { x : I16, y : I16 }

Unit : { id : I8, moveRate: F32, player : Player, position : Point, cell : Doubled, dest : Doubled, sprite : Sprite, lastPath: List Doubled }

getPadOwner : List Unit, LaunchPad -> [Owned Player, Unowned]
getPadOwner = \units, pad ->
    byPlayer = List.walk pad [] \accum, cell ->
        List.findFirst units \u -> u.cell == cell
        |> Result.map \u -> List.append accum u.player
        |> Result.withDefault accum
    (player1, player2) = List.walk byPlayer (0, 0) \accum, player ->
        when player is
            Player1 -> (accum.0 + 1, accum.1)
            Player2 -> (accum.0, accum.1 + 1)
    if player1 == player2 then
        Unowned
    else if player1 > 0 && player2 == 0 then
        Owned Player1
    else if player2 > 0 && player1 == 0 then
        Owned Player2
    else
        Unowned

countPadsByOwner = \owners ->
  List.walk owners (0, 0) \accum, owner ->
      when owner is
          Owned Player1 -> (accum.0 + 1, accum.1)
          Owned Player2 -> (accum.0, accum.1 + 1)
          _ -> accum

getLaunchStatus = \owners ->
    (player1, player2) = countPadsByOwner owners
    if player1 > player2 then
        InControl Player1
    else if player2 > player1 then
        InControl Player2
    else
        StaleMate

updateUnit : Unit, U32, MoveChoice, (Doubled -> Bool) -> Unit
updateUnit = \original, frameCount, move, cannotMoveTo ->
    { cell, dest, moveRate, lastPath } = original
    (newDest, newPath) =
        when move is
            Destination (unit, chosen) if unit.cell == cell ->
                if cannotMoveTo chosen then (cell, [])
                else (chosen, (cubeLerp cell chosen))
            _ -> (dest, lastPath)

    path = newPath
      # if newDest == dest then original.lastPath
      # else cubeLerp cell dest

    if dest == cell then
        { original & lastPath: path, dest: newDest }
    else
        newCell =
            List.get path 1
            |> Result.map \c -> if (cannotMoveTo c) then cell else c
            |> Result.withDefault cell
        destPoint = hexToPixel newCell
        moveCountDown = frameCount % (Num.round moveRate)

        if moveCountDown == 0 then
            { original & cell: newCell, lastPath: (List.dropFirst path 1), position: destPoint, dest: newDest }
        else
            sourceCell = hexToPixel cell
            progress = moveCountDown |> Num.toFrac |> Num.div moveRate
            x = lerp (Num.toI32 sourceCell.x) (Num.toI32 destPoint.x) progress
            y = lerp (Num.toI32 sourceCell.y) (Num.toI32 destPoint.y) progress
            {
                original & cell,
                lastPath: path,
                position: { x: Num.floor x, y: Num.floor y },
                dest: newDest
            }


Doubled : {
    row : I32,
    column : I32,
}
doubled : I32, I32 -> Doubled
doubled = \column, row ->
    { column, row }

pixelToHex = \{ x, y } ->
    base = 0.57735
    baseq = 0.6666667
    q = x |> Num.toF32 |> Num.mul baseq |> Num.div 8.0
    yy = y |> Num.toF32 |> Num.mul base
    xx = x |> Num.toF32 |> Num.mul -0.3333
    r = (xx + yy) |> Num.div 8.0
    roundCubic q r |> cubicToDouble

isCellOccupied : (List Unit) -> (Doubled -> Bool)
isCellOccupied = \units -> \cell ->
    List.any units \unit -> unit.cell == cell

hexDistance : Doubled, Doubled -> I32
hexDistance = \from, to ->
    dcol = Num.sub from.column to.column |> Num.abs
    drow = Num.sub from.row to.row |> Num.abs
    dcol + (Num.max 0 ((Num.sub drow dcol) |> Num.toFrac |> Num.div 2 |> Num.round))

roundCubic = \q, r ->
    s = (r + q) |> Num.mul -1.0
    qq = Num.round q
    rr = Num.round r
    ss = Num.round s
    qqDiff = Num.toF32 qq |> Num.sub (Num.toF32 q) |> Num.abs
    rrDiff = Num.toF32 rr |> Num.sub (Num.toF32 r) |> Num.abs
    ssDiff = Num.toF32 ss |> Num.sub (Num.toF32 s) |> Num.abs
    if qqDiff > rrDiff && qqDiff > ssDiff then
        { q: (ss + rr) |> Num.mul -1, s: ss, r: rr }
    else if rrDiff > ssDiff then
        { r: (qq + ss) |> Num.mul -1, q: qq, s: ss }
    else
        { s: (rr + qq) |>Num.mul -1, r: rr, q: qq }

hexToPixel : Doubled -> Point
hexToPixel = \{ row, column } -> {
    x: column |> Num.toI16 |> Num.mul hexWidth |> Num.add 2 |> Num.toI16,
    y: row |> Num.toI16 |> Num.mul hexHeight |> Num.add 3 |> Num.toI16,
}

cubicToDouble = \{ q, r } ->
    doubled q (2 * r + q)

lerp : I32, I32, F32 -> F32
lerp = \a, b, t ->
    aa = Num.toFrac a
    bb = Num.toFrac b
    (bb - aa) |> Num.mul t |> Num.add aa

cubeLerp : Doubled, Doubled -> List Doubled
cubeLerp = \a, b ->
    n = hexDistance a b
    xs = List.range { start: At 0, end: At n }
    mul = 1 |> Num.div (Num.toFrac n)
    if n == 0 then
        [a]
    else
        List.walk xs [] \accum, i ->
            ii = mul |> Num.mul (Num.toFrac i)
            row = (lerp a.row b.row ii) |> Num.floor
            col = (lerp a.column b.column ii) |> Num.floor
            cell =
                if (row + col) % 2 == 0 then
                    doubled col row
                else
                    doubled col (row + 1)
            List.append accum cell

update : Model -> Task Model []
update = \model ->
    drawTitle! basePoint
    W4.setDrawColors! {primary: Color1, secondary: Color2, tertiary: Color3, quaternary: Color4 }
    when (updateBackground model) is
        GameOver state -> updateGameOver state
        TitleScreen state -> (state + 1) |> updateTitle
        InGame state -> updateFrameCount state |> updateInGame

updateFrameCount = \prev ->
    frameCount = Num.addWrap prev.frameCount 1
    { prev & frameCount }

getCurrentPlayer = \netplay ->
  when netplay is
    Enabled Player1 -> Player1
    Enabled Player2 -> Player2
    _ -> Player1

updateTitle = \frameCount ->
  msg = "Framecount = $(frameCount |> Num.toStr)"
  msg |> W4.text! { x: 30, y: 75 }
  netplay = W4.getNetplay!
  player = getCurrentPlayer netplay
  gamePad = W4.getGamepad! player
  if gamePad.button1 || gamePad.button2 then
    Task.ok (InGame newGame)
  else
    Task.ok (TitleScreen frameCount)


updateGameOver = \state ->
    { winner, palette: winnerPalette, frameCount } = state
    color = playerColor winner
    name = playerName winner
    elapsed = Num.toFrac frameCount |> Num.div 60.0 |> Num.round |> Num.toStr
    W4.setPalette! winnerPalette
    W4.setShapeColors! { border: Color4, fill: Color1 }
    W4.rect! { width: 140, height: 80, x: 10, y: 30 }

    W4.setShapeColors! { border: color, fill: color }
    W4.rect! { width: 138, height: 25, x: 11, y: 31 }

    W4.setTextColors! { fg: Color1, bg: None }
    "The " |> Str.concat name
    |> Str.concat "\nis victorious!!"
    |> W4.text! { x: 17, y: 35 }
    W4.setTextColors! { fg: Color4, bg: None }
    message =
        """
        After $(elapsed)
        long seconds,the
        $(name) Army
        wins the Battle
        of Petersberg!
        """
    message |> W4.text! { x: 17, y: 60 }
    (sprite, colors) = when winner is
        Player1 -> (Assets.dawn,  { primary: Color4, secondary: Color2, tertiary: Color3, quaternary: Color1 } )
        Player2 -> (Assets.flame, { primary: Color1, secondary: Color2, tertiary: Color3, quaternary: Color4 })

    W4.setDrawColors!  colors
    Sprite.blit! sprite { x: 0, y: 120 }

    Task.ok (GameOver state)

unitFromClick = \units, selected, choice ->
    List.findFirst units \u ->
        u.cell == selected && u.player == Player1
    |> Result.mapErr \_ -> {}
    |> Result.try \u ->
        when choice is
            Finished -> Ok (Selected u.id)
            Selected id ->
                if u.id == id then
                    Ok Finished
                else
                    Ok (Selected u.id)

            _ -> Err {}
basePoint : Point
basePoint = { x: 0, y: 18 }

boardRect = { x: basePoint.x |> Num.toI32,
    y: basePoint.y |> Num.toI32 |> Num.add 2,
    width: 160,
    height: 102
}
launchTimerToSeconds = \x -> Num.toFrac x |> Num.div 60

updateBackground : Model -> Model
updateBackground = \gameState ->
    when gameState is
        TitleScreen state -> TitleScreen state
        InGame state -> InGame (updateArt state)
        GameOver state ->
            when state.winner is
                Player1 -> GameOver state
                Player2 -> GameOver state

updateArt : GameState -> GameState
updateArt = \model ->
    if model.frameCount % 301 != 0 then
        model
    else
        totalBackgrounds = List.len model.backgrounds
        (Num.toU32 model.frameCount) % (Num.toU32 totalBackgrounds)
        |> \index -> List.get model.backgrounds (Num.toU64 index)
            |> Result.withDefault model.background
        |> \background ->{ model & background }

updateInGame = \model ->
    netplay = W4.getNetplay!

    padOwners = List.map model.launchPads \pad -> getPadOwner model.units pad
    thePlayer =
        when netplay is
            Enabled Player1 ->  Player1
            Enabled Player2 ->  Player2
            _ -> Player1

    gamePad = W4.getGamepad! thePlayer
    launchStatus = getLaunchStatus padOwners
    totalMs = model.launchIn |> launchTimerToSeconds |> Num.mul 1000 |> Num.round
    msRemaining = model.launchTimer |> launchTimerToSeconds |> Num.mul 1000 |> Num.round
    percentLeft = msRemaining |> Num.toFrac |> Num.div (Num.toFrac totalMs)
    isRedAlert = (msRemaining % 1000) |> Num.toFrac |> Num.div 1000 |> \fractionSecond -> fractionSecond > percentLeft
    playerPalette =
        when netplay is
            Enabled Player1 -> player1Palette
            Enabled Player2 -> player2Palette
            _ -> palette
    colors =
        if msRemaining <= 15000 then
            when launchStatus is
                InControl _ if isRedAlert -> redPalette
                _ -> playerPalette
        else
            playerPalette

    W4.setPalette! colors

    launchTimer =
        if model.launchTimer <= 0 then
            model.launchTimer
        else
            when launchStatus is
                InControl _ -> Num.sub model.launchTimer 1
                StaleMate -> model.launchTimer


    hoverCell = model.p1HoverCell
        |> \{row, column} -> if gamePad.up && Bool.not model.lastGamepad.up then { row: row - 2, column } else { row, column }
        |> \{row, column} -> if gamePad.down && Bool.not model.lastGamepad.down then { row: row + 2, column } else { row, column }
        |> \{row, column} -> if gamePad.left && Bool.not model.lastGamepad.left then { row: row + 1, column: column - 1} else { row, column }
        |> \{row, column} -> if gamePad.right && Bool.not model.lastGamepad.right then { row: row + 1, column: column + 1} else { row, column }

    isOccupied = isCellOccupied model.units

    moveChoice =
        if gamePad.button1 && !model.lastGamepad.button1 then
            selected = hoverCell
            badMove = isOccupied selected
            default =
                when (model.moveChoice) is
                    (Finished) ->
                        model.units
                        |> List.findFirst \{ cell, player } ->
                            cell == hoverCell && player == player
                        |> Result.map \u -> Selected u.id
                        |> Result.withDefault Finished
                    (Selected id) ->
                        dest = hoverCell
                        List.get model.units (Num.toU64 id)
                        |> Result.map \u ->
                            if u.cell == dest then
                                Finished
                            else if (badMove) then
                                Selected id
                            else
                                Destination (u, dest)
                        |> Result.withDefault (Selected id)
                    _ -> Finished

            unitFromClick model.units selected model.moveChoice
            |> Result.withDefault default
        else
            when model.moveChoice is
                Destination (unit, _) -> Selected unit.id
                _ -> model.moveChoice

    selectedDestinationPath =
        when moveChoice is
            Selected id ->
                List.get model.units (Num.toU64 id)
                |> Result.map \{ lastPath } -> lastPath
                |> Result.withDefault []

            _ -> []

    plannedPath =
        when moveChoice is
            Selected id ->
                List.get model.units (Num.toU64 id)
                |> Result.map \unit -> cubeLerp unit.cell hoverCell
                |> Result.withDefault []

            _ -> []

    units = List.map model.units \u -> updateUnit u model.frameCount moveChoice isOccupied


    launchStateColor =
        when launchStatus is
            InControl player -> playerColor player
            StaleMate -> Color4

    state = {
        model & moveChoice,
        lastGamepad: gamePad,
        p1HoverCell: hoverCell,
        launchTimer, units
    }


    W4.setShapeColors! { border: Color4, fill: Color1 }
    W4.rect! boardRect

    W4.setShapeColors! { border: Color4, fill: None }
    # drawGrid! model.obstacles Assets.filledHex basePoint
    drawPads = List.walk model.launchPads (Task.ok {}) \task, launchPad ->
        task!
        drawLaunchPad launchPad (getPadOwner model.units launchPad) Assets.hex

    drawUnits! model.units basePoint model.moveChoice
    drawPads!

    task = when model.moveChoice is
        Selected _ -> drawPaths hoverCell Assets.hex plannedPath selectedDestinationPath
        _ ->
            _ <- W4.setTextColors { fg: None, bg: Color3 } |> Task.await
            drawHex hoverCell basePoint Assets.hex
    task!



    drawLaunchTimer! launchStateColor msRemaining totalMs
    drawBottomImage! model.background

    # netPlayStatus |> W4.text! { x: 0, y: Num.toI32 (boardRect.height - 20)}

    if launchTimer > 0 then
        Task.ok (InGame state)
    else
        when launchStatus is
            InControl winner ->
                winnerPalette = when winner is
                    Player1 -> state.palettes.1
                    Player2 -> state.palettes.2
                gameOverState : GameOverState
                gameOverState = { winner, palette: winnerPalette, frameCount: state.frameCount }
                Task.ok (GameOver gameOverState)
            StaleMate -> Task.ok (InGame { state & launchTimer: 1 })

drawGrid = \cubes, sprite, point ->
    List.walk cubes (Task.ok {}) \task, cell ->
        task!
        drawHex cell point sprite

drawBottomImage = \sprite ->
    W4.setDrawColors! {
        primary: Color1, secondary: Color2, tertiary: Color3, quaternary: Color4
    }
    Sprite.blit! sprite { x: 0, y: 160 - 40 }
    # y = Num.toI32 boardRect.y |> Num.add (Num.toI32 boardRect.height)
    W4.setShapeColors! { border: Color4, fill: None }
    W4.rect! {
        x: boardRect.x,
        y: 160 - 40,
        width: boardRect.width,
        height: 40,
    }

cubePathToLine = \path, bp ->
    List.map path \cell ->
        point = hexToPixel cell
        {
            x: (point.x + bp.x) |> Num.toI32,
            y: (point.y + bp.y) |> Num.toI32,
        }

drawPath = \path ->
    List.walkWithIndex path (Task.ok {}) \task, from, i ->
        task!
        List.get path (i + 1)
        |> Result.map \to -> W4.line from to
        |> Result.withDefault (Task.ok {})

drawPaths = \hoverCell, sprite, primaryPath, destPath ->

    W4.setPrimaryColor! Color3
    drawPath! (cubePathToLine primaryPath basePoint)

    W4.setPrimaryColor! Color4
    drawPath! (cubePathToLine destPath basePoint)

    _ <- W4.setTextColors { fg: None, bg: Color3 } |> Task.await
    drawHex! hoverCell basePoint sprite
    f =
        List.last destPath
        |> Result.map \cell -> drawHex cell basePoint sprite
        |> Result.withDefault (Task.ok {})
    W4.setTextColors! { fg: None, bg: Color4 }
    f!

drawHex = \cell, point, sprite ->
    x = point.x |> Num.add (cell.column |> Num.toI16 |> Num.mul hexWidth) |> Num.sub halfWidth
    y = point.y |> Num.add (cell.row |> Num.toI16 |> Num.mul hexHeight) |> Num.sub halfHeight
    Sprite.blit sprite { x: Num.toI32 x, y: Num.toI32 y }

drawUnit = \unit, bp, choice ->
    drawTo = {
        x: (unit.position.x + bp.x - 4) |> Num.toI32,
        y: (unit.position.y + bp.y - 4) |> Num.toI32,
        flags: if unit.player == Player2 then
            [FlipX]
        else
            [],
    }

    border = playerColor unit.player
    fill =
        if unit.player == Player2 then
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
    W4.setShapeColors! { border: Color3, fill: Color4 }
    W4.rect! { height: point.y - 2 |> Num.toU32, width: 160, x: 0, y: 1 }
    W4.setTextColors! { bg: None, fg: Color1 }
    # W4.text! "      1864     " { x: 10, y: 5 }
    W4.text! " Year of Decision" { x: 10, y: 6 }
    W4.setDrawColors! { primary: None, secondary: Color2, tertiary: Color3, quaternary: Color4 }

drawLaunchTimer = \color, remaining, total ->
    W4.setTextColors! { bg: None, fg: color }
    totalWidth = hexWidth |> Num.mul 3 |> Num.sub hexWidth |> Num.toFrac

    barX = Num.round (80 - ( totalWidth / 2 )) |> Num.sub halfWidth |> Num.toI32
    barY = boardRect.height |> Num.toFrac |> Num.div 2 |> Num.round |> Num.add hexHeight |> Num.toI32
    windowDims = {width: (totalWidth + 10) |> Num.round, height: 20, x: barX - 5, y: (barY - 11)|>Num.abs }
    W4.setShapeColors! { border: Color2, fill: Color1 }
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
    W4.setTextColors! { bg: None, fg: Color4 }
    msg |> W4.text! { x, y: 49 }
    width =
        (Num.toFrac (total - remaining))
        |> Num.div (Num.toFrac total)
        |> Num.mul totalWidth
        |> Num.round
    W4.setShapeColors! { border: Color4, fill: None }
    W4.rect! { x: barX, y: barY, width: Num.round totalWidth, height: 5 }
    W4.setShapeColors! { border: Color4, fill: color }
    W4.rect! { x: barX, y: barY, width, height: 5 }

drawLaunchPad = \pad, owner, sprite ->
    color =
        when owner is
            Owned p -> playerColor p
            Unowned -> Color4
    W4.setTextColors! { fg: None, bg: color }
    drawGrid! pad sprite basePoint


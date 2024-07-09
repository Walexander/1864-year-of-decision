app [main, Model] {
    w4: platform "../platform/main.roc",
}

import w4.Task exposing [Task]
import w4.W4
import w4.Sprite exposing [Sprite]

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

Model : [InGame GameState, GameOver (Player, GameState)]
GameState : {
    fruitSprite : Sprite,
    moveChoice : MoveChoice,
    launchTimer : U8,
    launchIn : U8,
    arrow : Sprite,
    launchPads : LaunchPads,
    lastFrameClick : Bool,
    frameCount : U32,
    units : List Unit,
}

fruitSprite = Sprite.new {
    data: [
        0b00000111,
        0b11100000,
        0b00001000,
        0b00010000,
        0b00010000,
        0b00001000,
        0b00100000,
        0b00000100,
        0b01000000,
        0b00000010,
        0b10000000,
        0b00000001,
        0b01000000,
        0b00000010,
        0b00100000,
        0b00000100,
        0b00010000,
        0b00001000,
        0b00001000,
        0b00010000,
        0b00000111,
        0b11100000,
    ],
    bpp: BPP1,
    width: 16,
    height: 12,
}

filledSprite = Sprite.new {
    data: [
        0b00000000,
        0b00000000,
        0b00000111,
        0b11100000,
        0b00001111,
        0b11110000,
        0b00011111,
        0b11111000,
        0b00111111,
        0b11111100,
        0b01111111,
        0b11111110,
        0b00111111,
        0b11111100,
        0b00011111,
        0b11111000,
        0b00001111,
        0b11110000,
        0b00000111,
        0b11100000,
        0b00000000,
        0b00000000,
    ],
    bpp: BPP1,
    width: 16,
    height: 12,
}

# flameSprite = Sprite.new {
#     data: [
#         0b00001000,
#         0b01001100,
#         0b01011100,
#         0b01100100,
#         0b11101110,
#         0b11111100,
#         0b11111110,
#         0b11111110,
#     ],
#     bpp: BPP1,
#     width: 8,
#     height: 8,
# }
main = { init, update }
init : Task Model []
init =
    palette = {
        color1: 0xdad3af,
        color2: 0xd58863,
        color3: 0xc23a73,
        color4: 0x2c1e74,
    }
    # palette = {
    #     color1: 0xe6e6c0,
    #     color2: 0xb494b7,
    #     color3: 0x42436e,
    #     color4: 0x26013f,
    # }
    W4.setPalette! palette
    arrowSprite = Sprite.new {
        data: [
            0b00001000,
            0b00001100,
            0b01111110,
            0b01111111,
            0b01111110,
            0b00001100,
            0b00001000,
            0b00000000,
        ],
        bpp: BPP1,
        width: 8,
        height: 8,
    }
    unit1 = {
        id: 0,
        position: hexToPixel (doubled 1 3),
        player: Player1,
        cell: doubled 1 3,
        dest: doubled 1 3,
        sprite: arrowSprite,
    }
    unit2 : Unit
    unit2 = {
        id: 1,
        player: Player1,
        position: hexToPixel (doubled 1 1),
        cell: doubled 1 1,
        dest: doubled 1 1,
        sprite: arrowSprite,
    }
    unit3 : Unit
    unit3 = {
        id: 2,
        player: Player2,
        position: hexToPixel (doubled 11 1),
        cell: doubled 11 1,
        dest: doubled 9 5,
        sprite: arrowSprite,
    }
    launchIn = 15
    Task.ok
        (
            InGame {
                arrow: arrowSprite,
                moveChoice: Finished,
                frameCount: Num.toU32 0,
                launchIn,
                launchTimer: launchIn,
                fruitSprite,
                units: [unit1, unit2, unit3],
                launchPads: [
                    [
                        doubled 5 7,
                        doubled 5 5,
                        doubled 4 6,
                    ],
                    [
                        doubled 7 7,
                        doubled 7 5,
                        doubled 8 6,
                    ]
                ],
                lastFrameClick: Bool.false,
            }
        )

hexWidth : I16
hexWidth = 12
hexHeight : I16
hexHeight = 6
halfWidth : I16
halfWidth = 6
halfHeight : I16
halfHeight = 3

Point : { x : I16, y : I16 }

Unit : { id : I8, player : Player, position : Point, cell : Doubled, dest : Doubled, sprite : Sprite }

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
    if player1 > player2 then
        Owned Player1
    else if player2 > player1 then
        Owned Player2
    else
        Unowned

countPadsByOwner = \owners ->
  List.walk owners (0, 0) \accum, owner ->
      when owner is
          Owned Player1 -> (accum.0 + 1, accum.1)
          Owned Player2 -> (accum.0, accum.1 + 1)
          _ -> accum

launchState = \owners ->
    (player1, player2) = countPadsByOwner owners
    if player1 > player2 then
        InControl Player1
    else if player2 > player1 then
        InControl Player2
    else
        StaleMate

# updateUnit : Unit, U32, MoveChoice, (Doubled -> Bool) -> Unit
updateUnit = \original, frameCount, move, cannotMoveTo ->
    { cell, position, dest, sprite } = original
    newDest =
        when move is
            Destination (unit, chosen) ->
                if cell == unit.cell then
                    chosen
                else
                    dest

            _ -> dest
    if frameCount % 60 == 0 then
        path = cubeLerp cell dest
        newCell =
            List.get path 1
            |> Result.map \c ->
                if (cannotMoveTo c) then
                    cell
                else
                    c
            |> Result.withDefault cell
        { original & cell: newCell, position: hexToPixel newCell, dest: newDest, sprite }
    else
        { original & cell, position, sprite, dest: newDest }

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
    qq = Num.round q
    rr = Num.round r
    ss = (rr + qq) |> Num.mul -1
    { q: qq, r: rr, s: ss }

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
            row = (lerp a.row b.row ii) |> Num.round
            col = (lerp a.column b.column ii) |> Num.round
            cell =
                if (row + col) % 2 == 0 then
                    doubled col row
                else
                    doubled col (row + 1)
            List.append accum cell

update : Model -> Task Model []
update = \model ->
    drawTitle! basePoint
    when model is
        InGame state -> updateFrameCount state |> updateInGame
        GameOver (winner, state) -> updateGameOver winner state

updateFrameCount : { frameCount : U32 }a -> { frameCount : U32 }a
updateFrameCount = \prev ->
    frameCount = Num.addWrap prev.frameCount 1
    { prev & frameCount }

updateGameOver = \winner, state ->
    color = playerColor winner
    name = playerName winner
    elapsed = Num.toFrac state.frameCount |> Num.div 60.0 |> Num.round |> Num.toStr
    W4.setShapeColors! { border: Color4, fill: Color1 }
    W4.rect! { width: 140, height: 100, x: 10, y: 30 }
    W4.setShapeColors! { border: color, fill: color }
    W4.rect! { width: 138, height: 20, x: 11, y: 31 }
    W4.setTextColors! { fg: Color1, bg: color }
    name |> Str.concat " Wins!" |> W4.text! { x: 12, y: 35 }
    W4.setTextColors! { fg: Color4, bg: None }
    message =
        """
        In a battle
        for the ages,
        after $(elapsed)
        long seconds,the
        $(name) Army
        is victorious!
        """
    message |> W4.text! { x: 12, y: 60 }
    Task.ok (GameOver (winner, state))

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
basePoint = { x: 0, y: 30 }
updateInGame = \model ->
    mouse = W4.getMouse!
    mousePoint = { x: mouse.x |> Num.sub basePoint.x, y: mouse.y |> Num.sub basePoint.y }

    padOwners = List.map model.launchPads \pad -> getPadOwner model.units pad

    # launchStatus = launchState model.units model.launchPads
    launchStatus = launchState padOwners

    launchTimer =
        if model.frameCount % 60 != 0 || model.launchTimer <= 0 then
            model.launchTimer
        else
            when launchStatus is
                InControl _ -> Num.sub model.launchTimer 1
                StaleMate -> model.launchTimer

    hoverCell =
        when model.moveChoice is
            Destination (_, dest) -> dest
            _ -> pixelToHex mousePoint

    isOccupied = isCellOccupied model.units
    moveChoice =
        if mouse.left && !model.lastFrameClick then
            selected = pixelToHex mousePoint
            badMove = isOccupied selected
            default =
                when model.moveChoice is
                    Finished ->
                        model.units
                        |> List.findFirst \{ cell, player } ->
                            cell == selected && player == Player1
                        |> Result.map \u -> Selected u.id
                        |> Result.withDefault Finished

                    Selected id ->
                        dest = selected
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
                |> Result.map \{ cell, dest } -> cubeLerp cell dest
                |> Result.withDefault []

            _ -> []

    plannedPath =
        when moveChoice is
            Selected id ->
                List.get model.units (Num.toU64 id)
                |> Result.map \unit -> cubeLerp unit.cell hoverCell
                |> Result.withDefault []

            _ -> []
    W4.setShapeColors! { border: Color4, fill: Color1 }
    W4.rect! { height: 80, width: 160, x: 0, y: Num.toI32 basePoint.y }

    launchStateColor =
        when launchStatus is
            InControl player -> playerColor player
            StaleMate -> Color4

    drawLaunchTimer! launchStateColor model.launchTimer model.launchIn
    W4.setTextColors! { fg: None, bg: Color2 }

    drawPads = List.walk model.launchPads (Task.ok {}) \task, launchPad ->
        task!
        drawLaunchPad launchPad (getPadOwner model.units launchPad) model.fruitSprite

    drawPads!
    drawUnits! model.units basePoint model.moveChoice
    drawPaths! hoverCell model.fruitSprite plannedPath selectedDestinationPath
    winningPlayer = when launchStatus is
        StaleMate -> "NONE"
        InControl player -> playerName player

    """
    launchState
    $(winningPlayer)
    """
    |> W4.text! {x: 10, y: 122 }

    units = List.map model.units \u -> updateUnit u model.frameCount moveChoice isOccupied
    state = { model & moveChoice, launchTimer, units, lastFrameClick: mouse.left }

    if launchTimer > 0 then
        Task.ok (InGame state)
    else
        when launchStatus is
            InControl winner -> Task.ok (GameOver (winner, state))
            StaleMate -> Task.ok (InGame { state & launchTimer: 1 })

drawGrid = \cubes, sprite, point ->
    List.walk cubes (Task.ok {}) \task, cell ->
        task!
        drawHex cell point sprite

drawPath = \path, bp ->
    List.walkWithIndex path (Task.ok {}) \task, cell, i ->
        task!
        point = hexToPixel cell
        from = {
            x: (point.x + bp.x) |> Num.toI32,
            y: (point.y + bp.y) |> Num.toI32,
        }
        next = List.get path (i + 1) |> Result.map \to -> hexToPixel to
        Result.map next \to ->
            xy = { x: (to.x + bp.x) |> Num.toI32, y: (bp.y + to.y) |> Num.toI32 }
            W4.line from xy
        |> Result.withDefault (Task.ok {})

drawPaths = \hoverCell, sprite, primaryPath, destPath ->
    W4.setPrimaryColor! Color3
    drawPath! primaryPath basePoint
    W4.setPrimaryColor! Color4
    drawPath! destPath basePoint

    _ <- W4.setTextColors { fg: None, bg: Color3 } |> Task.await
    drawHex! hoverCell basePoint sprite
    _ <- W4.setTextColors { fg: None, bg: Color4 } |> Task.await

    f =
        List.last destPath
        |> Result.map \cell -> drawHex cell basePoint sprite
        |> Result.withDefault (Task.ok {})
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
    W4.text! "      1864     " { x: 10, y: 5 }
    W4.text! " Year of Decision" { x: 10, y: 16 }
    W4.setDrawColors! { primary: None, secondary: Color2, tertiary: Color3, quaternary: Color4 }

drawLaunchTimer = \color, remaining, total ->
    W4.setTextColors! { bg: None, fg: color }
    _ <- (
            if remaining < 10 && remaining > 0 then
                W4.text (Inspect.toStr remaining) { x: 71, y: 65 }
            else
                Task.ok {}
        )
        |> Task.await
    width =
        (Num.toFrac remaining) |> Num.div (Num.toFrac total) |> Num.mul 158.0 |> Num.round
    W4.setShapeColors! { border: Color4, fill: color }
    W4.rect! { x: 1, y: 104, width, height: 5 }
    W4.setTextColors! { bg: Color3, fg: Color2 }

drawLaunchPad = \pad, owner, sprite ->
    color =
        when owner is
            Owned p -> playerColor p
            Unowned -> Color4

    W4.setTextColors! { fg: None, bg: color }
    drawGrid! pad sprite basePoint

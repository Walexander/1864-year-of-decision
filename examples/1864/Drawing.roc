module [drawPads, resetColors, drawBottomImage, drawTitle, drawUnits, drawBoardRect, drawPlayerMove, drawHoverPositon, drawGrid, drawLaunchPad, drawLaunchTimer, drawGameTime]
import w4.W4
import w4.Sprite
import w4.Task exposing [Task]
import Assets
import Hex
import Health

basePoint : Hex.Point
basePoint = { x: 5, y: 20 }

boardRect = {
    x: basePoint.x |> Num.toI32,
    y: basePoint.y |> Num.toI32,
    width: Num.toU32 150,
    height: Num.toU32 100,
}

drawPads = \launchPads, getOwner ->
    List.walk launchPads (Task.ok {}) \task, launchPad ->
        task!
        drawLaunchPad launchPad (getOwner launchPad) Assets.hex
drawGameTime = \elapsedSeconds ->
    W4.setShapeColors! { fill: Color2, border: Color4 }
    offsetX : I32
    offsetX = 32
    W4.oval! {
        x: 160 - offsetX - 10,
        y: boardRect.y - 5,
        width: 30,
        height: 20,
    }
    W4.setTextColors! { fg: Color1, bg: None }
    size = Str.countUtf8Bytes elapsedSeconds
    minusX = Num.toI32 (size - 1) * 4
    elapsedSeconds
        |> W4.text! {
            x: 160 - offsetX - minusX,
            y: (boardRect.y + 2),
        }

drawBoardRect = \rect ->
    W4.setShapeColors! { fill: Color3, border: Color3 }
    W4.rect! {
        x: 0,
        y: boardRect.y - 5,
        width: 160,
        height: boardRect.height + 10,
    }
    W4.setShapeColors! { fill: Color1, border: Color1 }
    W4.rect rect

armyColor = \army ->
    when army is
        Union -> Color2
        Confederates -> Color3

drawLaunchPad = \pad, owner, sprite ->
    color =
        when owner is
            Owned p -> armyColor p
            Unowned -> Color4
    W4.setTextColors! { fg: None, bg: color }
    drawGrid! pad sprite boardRect

drawGrid = \cubes, sprite, point ->
    List.walk cubes (Task.ok {}) \task, cell ->
        task!
        Hex.drawHex cell point sprite

drawPath = \path ->
    List.walkWithIndex path (Task.ok {}) \task, from, i ->
        task!
        List.get path (i + 1)
        |> Result.map \to -> W4.line from to
        |> Result.withDefault (Task.ok {})

drawPaths = \plannedPath, destPath, starting ->
    position = {
        x: starting.x + boardRect.x,
        y: starting.y + boardRect.y
    }

    plannedLine =
        Hex.pathToLine plannedPath boardRect
        |> List.set 0 position
    destLine = Hex.pathToLine destPath boardRect
        |> List.set 0 position

    drawPath! destLine

    _ <-
        List.last destPath
        |> Result.map \cell -> drawHoverPositon cell
        |> Result.withDefault (Task.ok {})
        |> Task.await
    W4.setPrimaryColor! Color4
    drawPath plannedLine

drawHoverPositon = \cell ->
    point = Hex.hexToPixel cell
    # xoffset = Hex.halfWidth |> Num.toFrac |> Num.div 2 |> Num.round
    # yoffset = Hex.halfHeight |> Num.toFrac |> Num.div 2 |> Num.round

    # # width = xoffset * 2 |> Num.toU32
    # height = yoffset * 2 |> Num.toU32
    x = point.x |> Num.add boardRect.x
    y = point.y |> Num.add boardRect.y
    W4.line! { x: x - 2, y: y } { x: x + 2, y }
    W4.line { x: x, y: y - 2 } { x, y: y  + 2 }

drawPlayerMove = \move, _hovering, get, color, _isBlocked ->
    W4.setPrimaryColor! color
    when move is
        Selected id planned ->
            unit = get id
            (starting, destination) =
                unit
                |> Result.map \{lastPath, position} -> (position, lastPath)
                |> Result.withDefault ({ x: 0, y: 0}, [])
            drawPaths planned destination starting

        Finished | Destination (_, _) -> Task.ok {}

drawUnit = \unit, bp, choice, theArmy ->
    point = {
        x: (unit.position.x + bp.x - 4) |> Num.toI32,
        y: (unit.position.y + bp.y - 4) |> Num.toI32,
    }
    drawTo = {
        x: point.x,
        y: point.y,
        flags: if unit.army != theArmy then
            [FlipX]
        else
            [],
    }
    border = armyColor unit.army
    fill =
        if unit.army == theArmy then
            Color4
        else
            when choice is
                Selected id _ -> if unit.id == id then Color2 else None
                _ -> None

    W4.setShapeColors! { border: fill, fill: None }
    blitHexagon! unit.cell { x: boardRect.x, y: boardRect.y + 1 } Assets.hex
    W4.setShapeColors { border, fill }
    |> Task.await \_ -> Sprite.blit unit.sprite drawTo
    |> Task.await \_ ->
        when unit.health is
            Living hp ->
                drawHealthBar hp {
                    x: point.x - 2,
                    y: point.y + Hex.hexHeight + 3,
                }

            Dead _ -> Task.ok {}

drawUnits = \units, bp, choice, theArmy ->
    List.walk units (Task.ok {}) \task, unit ->
        task!

        drawUnit unit bp choice theArmy

drawHealthBar : Health.Health, Hex.Point -> _
drawHealthBar = \health, point ->
    height = Num.toU32 3
    width = Hex.hexWidth |> Num.toFrac |> Num.round |> Num.toU32
    baseRect = {
        width,
        height,
        x: point.x |> Num.toI32,
        y: point.y |> Num.toI32,
    }
    healthPercent = Health.health health
    healthBar = Num.toFrac width |> Num.mul healthPercent |> Num.round
    healthRect = {
        height,
        width: healthBar |> Num.toU32,
        x: baseRect.x,
        y: baseRect.y,
    }
    W4.setShapeColors! { fill: Color3, border: Color1 }
    W4.rect! baseRect
    W4.setShapeColors! { fill: Color2, border: None }
    W4.rect healthRect


blitHexagon = \cell, point, sprite ->
    x = point.x |> Num.add (cell.column |> Num.mul Hex.hexWidth) |> Num.sub Hex.halfWidth |> Num.toI32
    y = point.y |> Num.add (cell.row |> Num.mul Hex.hexHeight) |> Num.sub Hex.halfHeight |> Num.toI32
    Sprite.blit sprite { x: Num.toI32 x, y: Num.toI32 y }

resetColors =
    W4.setDrawColors {
        primary: Color1,
        secondary: Color2,
        tertiary: Color3,
        quaternary: Color4,
    }

drawBottomImage = \sprite ->
    # W4.setShapeColors! { border: Color4, fill: Color1 }
    # W4.rect! {
    #     x: 1,
    #     y: 160 - 50,
    #     width: 158,
    #     height: 50,
    # }
    sub = Sprite.subOrCrash sprite { srcX: 0, srcY: 0, height: 40, width: 156 }
    resetColors!
    Sprite.blit! sub { x: 2, y: 160 - 45 }


drawTitle = \point ->
    W4.setShapeColors! { border: Color2, fill: Color4 }
    W4.rect! { height: point.y - 5 |> Num.toU32, width: 160, x: 0, y: 0 }
    W4.setTextColors! { bg: None, fg: Color1 }
    W4.text! " Year of Decision" { x: 10, y: 3 }
    resetColors

drawLaunchTimer = \remaining, total ->
    totalWidth = Hex.hexWidth |> Num.mul 3 |> Num.sub Hex.hexWidth |> Num.toFrac
    launchWindowHeight = 22
    launchWindowWidth = totalWidth + 12
    barX =
        Num.toFrac (boardRect.x + (Num.toI32 boardRect.width))
        |> Num.div 2
        |> Num.sub (launchWindowWidth / 2)
        |> Num.round
        |> Num.add 1
        |> Num.toI32

    barY =
        boardRect.height
        |> Num.add (Num.toU32 boardRect.y)
        |> Num.toFrac
        |> Num.div 2
        |> Num.round
        |> Num.sub (Num.round (Num.toFrac launchWindowHeight / 2))
        |> Num.sub (Num.round (Num.toFrac Hex.hexHeight / 2))
        |> Num.add 1
        |> Num.toI32

    windowDims = {
        width: launchWindowWidth |> Num.round,
        height: launchWindowHeight,
        x: barX,
        y: barY,
    }
    W4.setShapeColors! { border: Color2, fill: Color4 }
    W4.rect! windowDims
    msg =
        if remaining <= 0 then
            ""
        else if remaining < 10_000 then
            remaining
            |> Num.toFrac
            |> Num.div 100
            |> Num.round
            |> Num.toFrac
            |> Num.div 10
            |> Num.toStr
        else
            remaining |> Num.toFrac |> Num.div 1000 |> Num.round |> Num.toStr
    width =
        (Num.toFrac (total - remaining))
        |> Num.div (Num.toFrac total)
        |> Num.mul totalWidth
        |> Num.round

    baseX =
        windowDims.x
        |> Num.add (Num.round (Num.toFrac windowDims.width / 2))
        |> Num.sub (Num.round ((totalWidth) / 2))

    timerSize = Str.countUtf8Bytes msg
    W4.setShapeColors! { border: Color2, fill: None }
    launchBarX = baseX
    launchBarY =
        Num.toI32 windowDims.height
        |> Num.add barY
        |> Num.sub 10

    launchBar = {
        x: launchBarX,
        y: launchBarY,
        width: Num.round totalWidth,
        height: 6,
    }
    W4.rect! launchBar
    W4.setShapeColors! { border: Color1, fill: Color3 }
    # W4.rect! { x: baseX, y: barY + 8, width, height: 5 }
    W4.rect! { launchBar & width }

    x =
        Num.toFrac windowDims.x
        |> Num.add (Num.toFrac windowDims.width / 2)
        |> Num.sub (Num.toFrac timerSize |> Num.mul 8 |> Num.div 2)
        |> Num.round
    W4.setTextColors! { bg: None, fg: Color1 }
    msg |> W4.text! { x, y: barY + 3 |> Num.abs }

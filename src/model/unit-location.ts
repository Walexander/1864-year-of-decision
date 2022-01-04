import { Cube, equals as cubeEquals } from './coords/cube'
import { byPlayer, unitById } from './unit'
import { Unit } from './unit'
import { GameState } from '../game-state'
import * as A from 'fp-ts/Array'
import * as O from 'fp-ts/Option'
import * as U from './unit'
import { pipe } from 'fp-ts/function'
import { Cell } from './game-board'
import { indexFromCube } from './game-board'
import { Player } from './player'
export type UnitLocation = [Cube, Unit['unitId']]

export type MoveUnitCommand = {
	unitId: Unit['unitId']
	to: Cube
}

function findUnitIndex(
	unitId: Unit['unitId']
): (unitLocations: UnitLocation[]) => O.Option<number> {
	return (locations) =>
		pipe(
			locations,
			A.findIndex(([_, id]) => id === unitId)
		)
}

export function moveUnit(
	p: MoveUnitCommand
): (locations: UnitLocation[]) => UnitLocation[] {
	return (locations) =>
		pipe(
			locations,
			findUnitIndex(p.unitId),
			O.chain((index) =>
				pipe(
					locations,
					A.updateAt(index, [p.to, p.unitId] as UnitLocation)
				)
			),
			O.getOrElse(() => locations)
		)
}

export function unitsByCoord(coords: Cube): (state: GameState) => Unit[] {
	return function (state: GameState) {
		const { units, unitLocations } = state
		const todo = pipe(
			unitLocations,
			A.filter(([cell]) => cubeEquals(cell, coords)),
			A.map(([_, id]) => id),
			A.map((id) => unitById(id)(units)),
			A.compact
		)
		return todo
	}
}

export function cellIndexForUnit(
	unit: Unit
): (state: GameState) => O.Option<number> {
	return function (state) {
		const todo = pipe(
			state.unitLocations,
			coordForUnit(unit),
			O.chain((cube) => indexFromCube(cube)(state.hexgrid))
		)
		return todo
	}
}

export function coordForUnit(
	unit: Unit
): (unitLocations: GameState['unitLocations']) => O.Option<Cube> {
	return function (unitLocations) {
		return pipe(
			unitLocations,
			A.findFirst(([_, u]) => u === unit.unitId),
			O.map((location) => location[0])
		)
	}
}

export function coordHasConflict(coord: Cube): (G: GameState) => boolean {
	return (G) =>
		pipe(
			G,
			unitsByCoord(coord),
			A.map((u) => U.getUnitInfo(u)(G)),
			A.partition((u) => Player.CSAPlayer === u.player),
			({ left, right }) =>
				left.length > 0 &&
				right.length > 0 &&
				pipe(
					[...left, ...right],
					A.some((u) => U.MissionType.ATTACK === u.mission)
				)
		)
}

export function cellsInConflict(G: GameState): Cell.Cell[] {
	return pipe(
		G.hexgrid.cells,
		(a) => a.slice(),
		A.filter((a) => coordHasConflict(a.cube)(G))
	)
}
export function needsResolution(cell: Cell.Cell): (G: GameState) => boolean {
	return (G) =>
		pipe(
			G.inConflict,
			A.some((c) => cubeEquals(cell.cube, c.cube))
		)
}

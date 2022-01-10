import { GameState } from '../game-state'
import * as N from 'fp-ts/number'
import * as O from 'fp-ts/Option'
import * as E from 'fp-ts/Either'
import * as M from 'fp-ts/Monoid'
import * as SG from 'fp-ts/Semigroup'

import { concatAll } from 'fp-ts/Monoid'
import { not } from 'fp-ts/Predicate'
import { pipe, flow, identity } from 'fp-ts/function'
import * as UL from './unit-location'
import * as U from './unit'
import * as A from 'fp-ts/Array'
import * as SEP from 'fp-ts/Separated'
import { Player } from './player'
import * as Cube from './coords/cube'
import { Cell } from './game-board/cell'
import { BattleResult, Result as CombatResult, getCombatResult } from 'model/combat/result'
import {clamp} from 'fp-ts/Ord'
export * as Result from './combat/result'
SG.concatAll(SG.max(U.initiativeOrder))

export enum AttackType {
	REGULAR = 'regular',
	PROBE = 'probe',
	ALL_OUT = 'all_out',
}

export enum Strategy {
	Regular = 'regular',
	Flanking = 'flanking',
}

export interface AttackCommand {
	attackType: AttackType
	strategy?: Strategy
	commander: U.GameInfo
	commanded: U.GameInfo[]
}
export function getDefender(
	cell: Cell,
	attacker: Player
): (G: GameState) => U.GameInfo[] {
	return (G) =>
		pipe(
			G,
			UL.unitsByCoord(cell.cube),
			A.filter((unit) => unit.player !== attacker),
			A.map((u) => U.getUnitInfo(u)(G))
		)
}

export function resolveCell2(attacker: Player): (G: GameState) => GameState {
	return (G: GameState): GameState => {
		const cell = G.combatCell
		if (!cell) return G
		return pipe(
			G,
			resolveCombat(attacker, cell),
			updateAttackers,
			updateRoutedMission,
		)
	}
}

function updateRoutedMission(G: GameState): GameState {
	return {
		...G,
		missionList: pipe(
			G.routedList,
			Object.keys,
			A.reduce(G.missionList, (list, unitId) =>
				U.setUnitMission(unitId, U.MissionType.DEFEND)(list)
			)
		),
	}
}

export function getModifierTotal(modifiers: GameState['modifiers']): number {
	return pipe(
		Object.values(modifiers),
		M.concatAll(N.MonoidSum),
		clamp(N.Ord)(-5, 5),
	)
}

function resolveCombat(attacker: Player, cell: Cell): (G: GameState) => GameState {
	return (G) => {
		const ratio = getBattleCombatRatio(cell, attacker)(G)
		const result = pipe(
			G.modifiers,
			getModifierTotal,
			(modifier) => G.combat.roll + modifier,
			getCombatResult(ratio)
		)
		const strengthPoints = applyStrengthPointLosses(
			attacker,
			cell,
			result
		)(G)
		return {
			...G,
			combat: {...G.combat, result},
			strengthPoints,
			resolvedCells: [...G.resolvedCells, cell],
			routedList: applyRouted(attacker, cell, result)(G)
		}
	}
}

function updateAttackers(G: GameState): GameState {
	return {
			...G,
			attackers: pipe(
				G.attackers,
				A.map((u) => ({
					...u,
					commander: {
						...u.commander,
						sp: U.getStrength(u.commander)(G.strengthPoints),
					},
				}))
			),
	}
}

const concatStrPoints = SG.concatAll(U.strengthSemigroup)
function applyRouted(
	attacker: Player,
	cell: Cell,
	result: BattleResult
): (G: GameState) => GameState['routedList'] {
	return (G) => {
		const todo = pipe(
			SEP.separated(
				pipe(
					result.attacker.routed ? O.some(G.attackers): O.none,
					O.map(
						flow(
							A.map((a) => a.commander),
							A.map((u) => [u.unitId, true]),
							Object.fromEntries
						)
					)
				),
				pipe(
					result.defender.routed
						? O.some(getDefender(cell, attacker)(G))
						: O.none,
					O.map(
						flow(
							A.map((u) => [u.unitId, true]),
							Object.fromEntries
						)
					)
				)
			),
			SEP.bimap(
				O.fold(() => ({}), identity),
				O.fold(() => ({}), identity)
			)
		)
		return {
			...G.routedList,
			...todo.left,
			...todo.right,
		}
	}
}

export function resolveConflict(cell: Cell) {
	return (G: GameState) => pipe(
		G.inConflict,
		A.findIndex((c) => Cube.equals(c.cube, cell.cube)),
		O.chain((i) => A.deleteAt(i)(G.inConflict)),
		O.getOrElse(() => G.inConflict)
	)
}

export function applyStrengthPointLosses(
	attacker: Player,
	cell: Cell,
	result: BattleResult
): (G: GameState) => U.UnitStrength {

	return (G) => {
		const todo = pipe(
			SEP.separated(
				G.attackers.map((a) => a.commander),
				getDefender(cell, attacker)(G)
			),
			SEP.bimap(
				applyLoss(result.attacker),
				applyLoss(result.defender)
			)
		)
		return {
			...G.strengthPoints,
			...todo.left,
			...todo.right,
		}
	}
}


export function getBattleCombatRatio(
	combatCell: Cell,
	attacker: Player
): (G: GameState) => number {
	return (G) => {
		const attackers = pipe(
			G.attackers,
			A.map((a) => a.commander),
			getStrengthPoints
		)
		const defenders = pipe(
			G,
			getDefender(combatCell, attacker),
			getStrengthPoints
		)
		return getRatio(attackers, defenders)
	}
}
function applyLossWithPOW(
totalUnits: number,
		result: CombatResult
): (index: number, unit: U.GameInfo) => U.UnitStrength {
	const { loss, pows } = result
	return (index, unit) => ({
		[unit.unitId]:
			unit.sp -
			Math.round(unit.sp * loss) -
			Math.floor(pows / totalUnits) -
			(pows % (index + 1)),
	})
}

function applyLoss(
	result: CombatResult
): (units: U.GameInfo[]) => U.UnitStrength {
	return (units) =>
		pipe(
			units,
			A.mapWithIndex(applyLossWithPOW(units.length, result)),
			concatStrPoints({})
		)
}

export function musterTroops(commands: AttackCommand[]): U.GameInfo[] {
	return pipe(
		commands,
		A.map((a) => [...a.commanded, a.commander]),
		A.flatten
	)
}

export function minRoll(command: AttackCommand): number {
	const modifier = command.strategy === Strategy.Flanking ? -1 : 0
	return command.commander.initiativeRating + modifier
}

export function testMuster(
	command: AttackCommand
): (roll: number) => E.Either<AttackCommand[], AttackCommand[]> {
	const min = minRoll(command)
	return (roll) => {
		const todo = pipe(
			roll <= min ? E.right(command) : E.left(command),
			E.map(() => flatten(command)),
			E.mapLeft(() => destruct(command))
		)
		return todo
	}
}

function flatten(c: AttackCommand): AttackCommand[] {
	return [{ ...c, commanded: [] }, ...pipe(c, destruct)]
}

function destruct(c: AttackCommand): AttackCommand[] {
	return pipe(
		c.commanded,
		A.map((u) => ({
			...c,
			commander: u,
			commanded: [],
		}))
	)
}

export function getAttacker(G: GameState): (cell: Cell) => Player {
	const isAttacker = (unit: U.GameInfo) =>
		unit.mission === U.MissionType.ATTACK

	return (cell) => {
		const todo = pipe(
			G,
			UL.unitsByCoord(cell.cube),
			A.map((a) => U.getUnitInfo(a)(G)),
			A.filter(isAttacker),
			A.sort(U.initiativeOrder),
			A.head,
			O.fold(
				() => Player.UnionPlayer,
				(a) => a.player
			)
		)
		return todo
	}
}

export function getRatio(attacker: number, defender: number) {
	let r = (attacker / defender) * 100
	const remainder = r % 25
	
	return pipe(
		Math.round(r - remainder) / 100,
	)
}

export function getCommander(units: U.GameInfo[]): U.GameInfo {
	return pipe(
		units,
		A.sort(U.Ord),
		A.reverse,
		A.head,
		O.fold(() => units[0], identity)
	)
}

export function modifiedTacticalRating(
	tacticalRating: number
): (roll: number) => number {
	const adjustments = [
		[1, 2, 3, 4],
		[2, 3, 4, 4],
		[2, 3, 4, 5],
		[3, 3, 4, 5],
		[3, 4, 5, 6],
		[4, 5, 6, 6],
	]
	const column = tacticalRating - 2
	return (roll) => adjustments[roll - 1][column]
}

export function findClosestT<T>(table: Array<[number, T]>): (roll: number) => T {
	return (roll) => pipe(
		table,
		A.findLast( ([target]) => roll >= target),
		O.map( a => a[1] ),
		O.fold( () => table[0][1], identity )
	)
}

export const modifiedRatio2 = findClosestT<number>([
	[0.75, -1],
	[1, 0],
	[2.5, 1],
	[3, 2],
	[4, 3],
	[5, 4],
	[6, 5],
])

const qualityModifier = findClosestT<number>([
	[0.01, 1],
	[1, 2],
	[2.5, 3],
	[3.5, 4],
])



export function modifiedQuality(
	cell: Cell,
	attacker: Player
): (G: GameState) => number {
	return (G) => {
		const qualityAttacker = pipe(
			G.attackers,
			A.map((a) => a.commander),
			meanQuality
		)
		const qualityDefender = pipe(
			G,
			getDefender(cell, attacker),
			meanQuality
		)
		const delta = qualityAttacker - qualityDefender
		return qualityModifier(Math.abs(delta)) * delta > 0 ? 1 : -1
	}
}
export function modifiedFlanking(G: GameState): number {
	return pipe(
		G.attackers,
		A.filter((a) => a.strategy === Strategy.Flanking),
		(a) => a.length
	)
}
export function mean(xs: Array<number>) {
	return xs.length > 0 ? M.concatAll(N.MonoidSum)(xs) / xs.length : 0
}

function meanQuality(u: U.Unit[]): number {
	return pipe(
		u,
		A.filter(not(U.isHq)),
		A.map((u) => (u._tag == 'HQ' ? 0 : u.qualityRating)),
		mean
	)
}

export const getStrengthPoints = (infoList: U.GameInfo[]) =>
	pipe(
		infoList,
		A.map(({ sp }) => sp),
		concatAll(N.MonoidSum)
	)

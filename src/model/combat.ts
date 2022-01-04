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
import { toPlayer, Player } from './player'
import * as Cube from './coords/cube'
import { Cell } from './game-board/cell'
import { Ctx } from 'boardgame.io'
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
		const ratio = getBattleCombatRatio(cell, attacker)
		const modifiedRoll = G.combat.roll + G.combatModifier
		const cRatio = ratio(G)
		const result = getResult(cRatio, modifiedRoll)
		return {
			...G,
			combat: {
				...G.combat,
				result,
			},
		}
	}
}

export function resolveCell(cell: Cell, attacker: Player, roll: number) {
	const concatStr = SG.concatAll(U.strengthSemigroup)
	return (G: GameState): GameState => {
		const attackers = pipe(
			G.attackers,
			A.map((a) => a.commander)
		)
		const defenders = pipe(G, getDefender(cell, attacker))
		const units = SEP.separated(defenders, attackers)
		const result = pipe(
			units,
			SEP.bimap(getStrengthPoints, getStrengthPoints),
			(sep) => ({
				defender: SEP.left(sep),
				attacker: SEP.right(sep),
			}),
			({ attacker, defender }) => getRatio(attacker, defender),
			(r) => getResult(r, 1)
		)
		const updated = pipe(
			units,
			SEP.bimap(
				flow(A.map(applyLoss(result.losses[1])), concatStr({})),
				flow(A.map(applyLoss(result.losses[0])), concatStr({}))
			)
		)
		return {
			...G,
			combatCell: undefined,
			inConflict: pipe(
				G.inConflict,
				A.findIndex((c) => Cube.equals(c.cube, cell.cube)),
				O.chain((i) => A.deleteAt(i)(G.inConflict)),
				O.getOrElse(() => G.inConflict)
			),
			strengthPoints: concatStr(G.strengthPoints)([
				updated.left,
				updated.right,
			]),
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
function applyLoss(percentLost: number): (unit: U.GameInfo) => U.UnitStrength {
	return (unit) => ({
		[unit.unitId]: unit.sp - Math.floor(unit.sp * percentLost),
	})
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

export interface CombatResult {
	losses: [attacker: number, defender: number]
}

const getResult = (odds: number, roll: number): CombatResult => ({
	losses: [0.4, 0.1],
})

export function getRatio(attacker: number, defender: number) {
	let r = (attacker / defender) * 100
	const remainder = r % 25
	return Math.round(r - remainder) / 100
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

export function modifiedRatio(ratio: number): number {
	const adjustments = [
		[0.75, -1],
		[1, 0],
		[2.5, 1],
		[3, 2],
		[4, 3],
		[5, 4],
		[6, 5],
	]
	return pipe(
		adjustments,
		A.findLast(([target]) => ratio >= target),
		O.map((a) => a[1]),
		O.fold(() => 0, identity)
	)
}
export const modifiedRatio2 = findClosest([
	[0.75, -1],
	[1, 0],
	[2.5, 1],
	[3, 2],
	[4, 3],
	[5, 4],
	[6, 5],
])

function findClosest(
	adjustments: Array<[number, number]>
): (val: number) => number {
	return (val) =>
		pipe(
			adjustments,
			A.findLast(([target]) => val >= target),
			O.map((a) => a[1]),
			O.fold(() => 0, identity)
		)
}
const qualityModifier = findClosest([
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

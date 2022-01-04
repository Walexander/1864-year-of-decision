import { pipe } from 'fp-ts/function'
import * as ORD from 'fp-ts/Ord'
import * as N from 'fp-ts/number'
import * as O from 'fp-ts/Option'
import * as SG from 'fp-ts/Semigroup'
import * as UL from './unit-location'
import * as R from 'fp-ts/Record'
import * as A from 'fp-ts/Array'
import * as EQ from 'fp-ts/Eq'
import * as E from 'fp-ts/Either'
import { Player } from './player'
import { Cube } from './coords/cube'
import { GameState } from 'game-state'
export type Unit = HQUnit | CommandUnit
export type QualityRating = 1 | 2 | 3 | 4 | 5
export type BaseUnit = {
	player: Player
	moveLimit: number
	unitId: string
	initiativeRating: number
	tacticalRating: number
}
type BaseCommandUnit = BaseUnit & {
	qualityRating: QualityRating
}
export type StrengthPoints = number
export type UnitStrength = Record<UnitId, StrengthPoints>

export type CommandUnit = Corps | Cavalry | Infantry | Militia
type UnitId = Unit['unitId']
export interface HQUnit extends BaseUnit {
	_tag: 'HQ'
	commandSpan: number
}
export interface Corps extends BaseCommandUnit {
	_tag: 'Corps'
}
export interface Cavalry extends BaseCommandUnit {
	_tag: 'Cavalry'
}
export interface Infantry extends BaseCommandUnit {
	_tag: 'Infantry'
}
export interface Militia extends BaseCommandUnit {
	_tag: 'Militia'
}
export interface Garrison extends BaseCommandUnit {
	_tag: 'Garrison'
}
export const Eq: EQ.Eq<Unit> = {
	equals: (x, y) => x.unitId === y.unitId,
}
export const InfoEq: EQ.Eq<GameInfo> = {
	equals: (x, y) => x.unitId === y.unitId,
}
export const Ord: ORD.Ord<Unit> = {
	...Eq,
	compare: (first, second) => {
		const [a, b] = [first._tag, second._tag]
		if (Eq.equals(first, second)) return 0
		if (a === b)
			return first.initiativeRating > second.initiativeRating ? 1 : -1
		if (a === 'HQ') return 1
		if (b === 'HQ') return -1
		return first.initiativeRating > second.initiativeRating ? 1 : -1
	},
}
export const unitById = (needle: string) => (units: Unit[]) =>
	pipe(
		units,
		A.findFirst(({ unitId }) => unitId === needle)
	)

export function isHq(unit: Unit) {
	return unit._tag === 'HQ'
}
export const initiativeOrder: ORD.Ord<Unit> = ORD.fromCompare((first, second) =>
	N.Ord.compare(first.initiativeRating, second.initiativeRating)
)

export const byPlayer = (player: Player) => (units: Unit[]) =>
	pipe(
		units,
		A.partition((a) => a.player === player)
	)

export const byMission = (units: GameInfo[]) =>
	pipe(
		units,
		A.partition((a) => a.mission == MissionType.ATTACK)
	)

export enum MissionType {
	DEFEND = 'defend',
	ATTACK = 'attack',
	NULL = '',
}
export interface SetUnitMissionCommand {
	unitId: string
	mission: MissionType
}

export interface UnitMissionList extends Record<string, MissionType> {}

export function setUnitMission(
	unitId: Unit['unitId'],
	mission: MissionType
): (missionList: UnitMissionList) => UnitMissionList {
	return (missionList) => ({
		...missionList,
		[unitId]: mission,
	})
}

export function unsetMission(
	unitId: UnitId
): (missionList: UnitMissionList) => UnitMissionList {
	return (missionList) => pipe(missionList, R.deleteAt(unitId))
}

export function getUnitMission({
	unitId,
}: Unit): (missionList: UnitMissionList) => MissionType {
	return (missionList) => missionList[unitId] || MissionType.NULL
}
export function getStrength(unit: Unit) {
	return (strengthList: UnitStrength) => strengthList[unit.unitId] || 0
}
export function setStrength(unit: Unit, strength: StrengthPoints) {
	return (strengthPoints: UnitStrength) =>
		pipe(strengthPoints, R.upsertAt(unit.unitId, strength))
}
export const strengthSemigroup: SG.Semigroup<UnitStrength> = {
	concat: (a: UnitStrength, b: UnitStrength) => ({
		...(a || {}),
		...(b || {}),
	}),
}

export type GameInfo = Unit & {
	sp: StrengthPoints
	location: Cube
	mission: MissionType
}

export function getUnitInfo(unit: Unit) {
	return (G: GameState): GameInfo => ({
		...unit,
		sp: getStrength(unit)(G.strengthPoints),
		location: pipe(
			G.unitLocations,
			UL.coordForUnit(unit),
			O.getOrElse(() => Cube(0, 0, 0))
		),
		mission: pipe(G.missionList, getUnitMission(unit)),
	})
}

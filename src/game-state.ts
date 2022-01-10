// import { Cube } from './model/coords/cube'
import { UnitLocation } from './model/unit-location'
import { Cube } from './model/coords/cube'
import { Cell, Board } from './model/game-board'
import { Unit, UnitMissionList } from './model/unit'
import * as RoundInfo from './model/round-info'
import * as Combat from './model/combat'
import * as U from './model/unit'
import { Player } from './model/player'
import { PlayerMoves } from './model/move-list'
import { BattleResult } from 'model/combat/result'

export interface CombatModifiers {
	tactical: number
	quality: number
	flanking: number
	ratio: number
}
export interface GameState {
	hexgrid: Board
	units: Unit[]
	weather: number
	modifiers: CombatModifiers
	strengthPoints: U.UnitStrength
	missionList: UnitMissionList
	roundInfo: RoundInfo.RoundInfo
	unitLocations: UnitLocation[]
	playerMoves: PlayerMoves
	completedPhase: number
	movesRemaining: number
	attackPlans: Combat.AttackCommand[]
	attackers: Combat.AttackCommand[]
	musterResult: string
	inConflict: Cell.Cell[]
	resolvedCells: Cell.Cell[]
	combatCell?: Cell.Cell
	lastRoll?: number
	nextOrder?: Combat.AttackCommand
	tacticalRoll: [number, number]
	routedList: Record<string, boolean>,
	combat: {
		roll: number
		modifier: number
		result?: BattleResult
	}
}

export const setup = (): GameState => ({
	weather: 0,
	completedPhase: 0,
	movesRemaining: Infinity,
	modifiers: {
		tactical: 0,
		ratio: 0,
		quality: 0,
		flanking: 0,
	},
	routedList: {},
	combat: {
		roll: 0,
		modifier: 0,
	},
	musterResult: '',
	attackPlans: [],
	attackers: [],
	hexgrid: Board({ columns: 5, rows: 3 }),
	playerMoves: PlayerMoves(),
	tacticalRoll: [0, 0],
	roundInfo: {
		round: 1,
		weather: 1,
		date: Number(new Date('May 1, 1864')),
	},
	units: [
		{
			_tag: 'HQ',
			unitId: 'Lee',
			commandSpan: 3,
			initiativeRating: 3,
			tacticalRating: 5,
			player: Player.CSAPlayer,
			moveLimit: 1,
		},
		{
			_tag: 'Corps',
			unitId: 'First',
			player: Player.CSAPlayer,
			qualityRating: 2,
			initiativeRating: 3,
			tacticalRating: 5,
			moveLimit: 1,
		},
		{
			_tag: 'HQ',
			unitId: 'Grant',
			player: Player.UnionPlayer,
			commandSpan: 3,
			initiativeRating: 4,
			tacticalRating: 4,
			moveLimit: 2,
		},
		{
			_tag: 'Corps',
			unitId: 'James',
			player: Player.UnionPlayer,
			qualityRating: 2,
			initiativeRating: 2,
			tacticalRating: 3,
			moveLimit: 1,
		},
		{
			_tag: 'HQ',
			unitId: 'Sherman',
			player: Player.UnionPlayer,
			commandSpan: 2,
			initiativeRating: 4,
			tacticalRating: 4,
			moveLimit: 1,
		},
		{
			_tag: 'Corps',
			unitId: 'Cumberland',
			player: Player.UnionPlayer,
			qualityRating: 3,
			initiativeRating: 3,
			tacticalRating: 4,
			moveLimit: 1,
		},
		{
			_tag: 'Corps',
			unitId: 'Ohio',
			player: Player.UnionPlayer,
			qualityRating: 4,
			initiativeRating: 3,
			tacticalRating: 4,
			moveLimit: 1,
		},
	],
	strengthPoints: {
		Lee: 30,
		First: 25,
		Grant: 50,
		James: 20,
		Sherman: 28,
		Ohio: 24,
		Cumberland: 24,
	},
	missionList: {},
	unitLocations: [
		[Cube(-1, 0, 1), 'Lee'] as UnitLocation,
		[Cube(0, 0, 0), 'First'] as UnitLocation,
		[Cube(1, 0, -1), 'Grant'] as UnitLocation,
		[Cube(0, 0, 0), 'James'] as UnitLocation,
		[Cube(0, 0, 0), 'Sherman'] as UnitLocation,
		[Cube(0, 0, 0), 'Cumberland'] as UnitLocation,
		[Cube(0, 0, 0), 'Ohio'] as UnitLocation,
	],
	inConflict: [],
	resolvedCells: [],
})

import * as BG from 'boardgame.io'
import * as A from 'fp-ts/Array'
import * as M from 'fp-ts/Monoid'
import * as N from 'fp-ts/number'
import * as E from 'fp-ts/Either'
import { pipe, identity, flow } from 'fp-ts/function'
import * as O from 'fp-ts/Option'
import { addMove } from './model/move-list'
import { ActivePlayers, INVALID_MOVE, Stage } from 'boardgame.io/core'

import * as B from './model/game-board'
import { Cell } from './model/game-board'
import { Player } from './model/player'
import * as Cube from './model/coords/cube'
import * as PM from './model/move-list'
import { toPlayer, otherPlayer } from './model/player'
import { GameState, setup } from './game-state'
import * as U from './model/unit'
import * as RoundInfo from './model/round-info'
import { MoveUnitCommand, moveUnit, coordForUnit } from './model/unit-location'
import * as UL from './model/unit-location'
import { unitById } from './model/unit'
import * as Combat from './model/combat'
import {and} from 'fp-ts/lib/Predicate'

export interface GameMoves {
	makeMove: (move: MoveUnitCommand) => void
	turnCrank: () => void
	endMovement: () => void
	startAttack: (c: Cell.Cell) => void
	rollFor: () => void
	planAttack: (c: Cell.Cell) => void
	musterTroops: (orders: Combat.AttackCommand[]) => void
	musterNext: () => void
	startCalculate: () => void
	startCharge: () => void
	combatRoll: () => void
	tacticalRoll: () => void
	surveyConflict: () => void
	setMission: (unit: U.Unit['unitId'], mission: U.MissionType) => void
}

export enum CombatStage {
	Plan = 'planAttack',
	Muster = 'musterTroops',
	Calculate = 'calculate',
	Charge = 'charge',
}
export const YearOfDecision = {
	setup,
	turn: {
		onEnd: onPhaseTurnComplete,
	},
	phases: {
		recover: {
			onEnd: resetCompleted,
			endIf,
			next: 'supply',
		},
		supply: {
			onEnd: resetCompleted,
			endIf,
			next: 'support',
		},
		support: {
			onEnd: resetCompleted,
			endIf,
			next: 'movement',
		},
		movement: {
			start: true,
			onEnd: resetCompleted,
			turn: {
				onBegin: (G: GameState) => ({
					...G,
					movesRemaining: Infinity,
				}),
				onEnd: (G: GameState, ctx: BG.Ctx) =>
					pipe(onMovementTurnEnd(G, ctx), onPhaseTurnComplete),
				endIf: (G: GameState, ctx: BG.Ctx) => {
					return false
					// if (G.movesRemaining <= 0) {
					// 	console.log(
					// 		'got a total of %s for %s',
					// 		G.movesRemaining,
					// 		ctx.currentPlayer
					// 	)
					// }
					// return G.movesRemaining <= 0
				},
			},
			endIf,
			moves: {
				turnCrank,
				makeMove,
				setMission,
			},
			next: 'combat',
		},
		combat: {
			next: 'recover',
			onEnd: flow(resetCompleted, onRoundEnd),
			endIf,
			turn: {
				onMove: startCalculate,
				onEnd: onPhaseTurnComplete,
				endIf: (G: GameState)  => G.inConflict.length <= 0,
				onBegin: (G: GameState, ctx: BG.Ctx) => ({
					...G,
					inConflict: getAttackingCells(G, ctx),
				}),
				stages: {
					[CombatStage.Plan]: {},
					[CombatStage.Muster]: {
						next: CombatStage.Calculate,
						endIf: (G: GameState) =>
							!!G.nextOrder && G.attackPlans.length < 1,
						moves: {
							musterNext,
							rollFor,
						},
					},
					[CombatStage.Calculate]: {
						next: CombatStage.Charge,
						moves: {
							tacticalRoll,
							startCharge,
						},
					},
					[CombatStage.Charge]: {
						moves: {
							surveyConflict,
						},
					},
				},
			},
			moves: { musterTroops, startAttack, turnCrank, planAttack },
		},
		endOfRound: {
			onEnd: (G: GameState) => ({
				...G,
				roundInfo: RoundInfo.startRound(G.roundInfo),
			}),
			turn: {},
			endIf: () => true,
			next: 'recover',
		},
	},
	moves: {
		startUp(G: GameState, ctx: BG.Ctx) {
			ctx.events?.setStage('recover')
			return G
		},
		turnCrank,
		recoverUnit(_: GameState) {
			return _
		},
	},
}

function getAttackingCells(G: GameState, ctx: BG.Ctx) {
	debugger
	const player = toPlayer(ctx.currentPlayer)
	const attackers = pipe(
		G,
		UL.cellsInConflict,
		A.filter(flow(Combat.getAttacker(G), (b) => player === b)),
		//A.difference(Cell.Eq)(G.resolvedCells)
	)
	return attackers
}

function onPhaseTurnComplete(G: GameState) {
	return {
		...G,
		completedPhase: G.completedPhase + 1,
	}
}

function startCharge(G: GameState, ctx: BG.Ctx): GameState | string {
	if (G.tacticalRoll[0] <= 0 || !G.combatCell) return INVALID_MOVE
	ctx.events?.endStage()
	const __ = pipe(
		combatRoll(G, ctx),
		Combat.resolveCell2(toPlayer(ctx.currentPlayer))
	)
	return __
}

function surveyConflict(G: GameState, ctx: BG.Ctx): GameState|string {
	const inConflict = G.combatCell ? 
		Combat.resolveConflict (G.combatCell) (G)
		: G.inConflict

	if(inConflict.length > 0)
		ctx.events?.setStage(CombatStage.Plan)
	else
		ctx.events?.endTurn()
	return {
		...G,
		combatCell: undefined,
		combat: {
			modifier: 0,
			roll: 0,
			result: undefined,

		},
		attackers: [],
		inConflict
	}
}

function combatRoll(G: GameState, ctx: BG.Ctx): GameState {
	return {
		...G,
		combat: {
			...G.combat,
			roll: ctx.random?.D6() || 0,
		},
	}
}

function startCalculate(G: GameState, ctx: BG.Ctx) {
	if (!G.combatCell) return G
	return pipe(
		{
			...G,
			modifiers: {
				...G.modifiers,
				quality: Combat.modifiedQuality(
					G.combatCell,
					toPlayer(ctx.currentPlayer)
				)(G),
				ratio: pipe(
					G,
					Combat.getBattleCombatRatio(
						G.combatCell,
						toPlayer(ctx.currentPlayer)
					),
					Combat.modifiedRatio2
				),
				flanking: Combat.modifiedFlanking(G),
			},
		},
		updateModifiers
	)
}

function updateModifiers(G: GameState): GameState {
	const modifier = pipe(Object.values(G.modifiers), M.concatAll(N.MonoidSum))

	return {
		...G,
		combatModifier: modifier,
		combat: {
			...G.combat,
			modifier,
		},
	}
}
function tacticalRoll(G: GameState, ctx: BG.Ctx): GameState {
	if (!G.combatCell) return G
	const player = toPlayer(ctx.currentPlayer)
	const ratings = [
		pipe(
			G.attackers,
			A.map((c) => c.commander),
			Combat.getCommander,
			(u) => u.tacticalRating
		),
		pipe(
			G,
			Combat.getDefender(G.combatCell, player),
			Combat.getCommander,
			(u) => u.tacticalRating
		),
	]

	const rolls = ctx.random?.D6(2) || [0, 0]
	const adjusted = [
		Combat.modifiedTacticalRating(ratings[0])(rolls[0]),
		Combat.modifiedTacticalRating(ratings[1])(rolls[1]),
	]
	const modifiers = {
		...G.modifiers,
		tactical: adjusted[0] - adjusted[1],
	}
	return pipe(
		{
			...G,
			tacticalRoll: [adjusted[0], adjusted[1]],
			modifiers,
		},
		updateModifiers
	)
}

function rollFor(G: GameState, ctx: BG.Ctx): GameState {
	const roll = ctx.random?.D6() || 0

	const todo = pipe(
		E.of(Combat.testMuster),
		E.ap(G.nextOrder ? E.right(G.nextOrder) : E.left([])),
		E.ap(E.of(roll)),
		E.chain((i) => i),
		E.foldW(
			(commands) => ({
				musterResult: 'failed',
				attackPlans: [...G.attackPlans, ...commands],
			}),
			(success) => ({
				musterResult: 'success',
				attackers: [...G.attackers, ...success],
			})
		)
	)
	return {
		...G,
		lastRoll: roll,
		...todo,
	}
}
function musterNext(G: GameState, ctx: BG.Ctx): GameState {
	const attackPlans = G.attackPlans
	const [nextOrder] = attackPlans.slice(0, 1)
	if (attackPlans.length < 1) ctx.events?.endStage()

	return {
		...G,
		nextOrder,
		lastRoll: undefined,
		musterResult: '',
		attackPlans: attackPlans.slice(1, attackPlans.length),
	}
}

function onMovementTurnEnd(G: GameState, ctx: BG.Ctx) {
	return {
		...G,
		...endMovement(G, ctx),
	}
}

function musterTroops(
	G: GameState,
	ctx: BG.Ctx,
	attackPlans: Combat.AttackCommand[]
): GameState {
	ctx.events?.setStage('musterTroops')
	return {
		...G,
		attackPlans,
	}
}
function planAttack(
	_: GameState,
	ctx: BG.Ctx,
	cell: Cell.Cell
): GameState | string {
	if (!A.elem(B.Cell.Eq)(cell)(_.inConflict)) return INVALID_MOVE

	ctx.events?.setStage('planAttack')
	return {
		..._,
		combatCell: cell,
	}
}

function startAttack(
	G: GameState,
	ctx: BG.Ctx,
	cell: Cell.Cell
): string | GameState {
	const player = toPlayer(ctx.currentPlayer)
	const roll = ctx.random?.D6() || 0
	const cellFinder = flow(A.elem(Cell.Eq)(cell))
	const todo = pipe(
		G,
		O.fromPredicate(({ inConflict }) => cellFinder(inConflict)),
		O.map(Combat.resolveCell(cell, player, roll)),
		O.foldW(() => INVALID_MOVE, identity)
	)
	return todo
}
function turnCrank(G: GameState, ctx: BG.Ctx) {
	ctx.events?.endTurn()
}

function setMission(
	G: GameState,
	_: BG.Ctx,
	unitId: U.Unit['unitId'],
	mission: U.MissionType
) {
	const player = toPlayer(_.currentPlayer)
	return pipe(G, ($G) => ({
		...$G,
		// playerMoves: pipe(G.playerMoves, addMove(player, { unitId, mission })),
		missionList: U.setUnitMission(unitId, mission)(G.missionList),
	}))
}

function endMovement(G: GameState, ctx: BG.Ctx) {
	const player = toPlayer(ctx.currentPlayer)
	return {
		...G,
		playerMoves: PM.reset(player)(G.playerMoves),
	}
}

function endIf(G: GameState): boolean {
	return G.completedPhase >= 2
}

function resetCompleted(G: GameState): GameState {
	return { ...G, completedPhase: 0 }
}

function makeMove(G: GameState, ctx: BG.Ctx, moveCommand: MoveUnitCommand) {
	const player = toPlayer(ctx.currentPlayer)
	return pipe(
		G,
		(state) => (isValidMove(moveCommand)(state) ? O.some(G) : O.none),
		O.map((G) => ({
			...G,
			missionList: U.unsetMission(moveCommand.unitId)(G.missionList),
		})),
		O.map(updateMove(player, moveCommand)),
		O.map(updateRemainingMoves(player, moveCommand)),
		O.getOrElseW(() => INVALID_MOVE)
	)
}

function updateRemainingMoves(player: Player, move: any) {
	return (G: GameState) => ({
		...G,
		movesRemaining: PM.movesRemaning(player)(G),
	})
}

export const updateMove =
	(player: Player, moveCommand: MoveUnitCommand) => (G: GameState) => {
		return {
			...G,
			unitLocations: moveUnit(moveCommand)(G.unitLocations),
			playerMoves: pipe(G.playerMoves, addMove(player, moveCommand)),
		}
	}

function isValidMove(moveCommand: MoveUnitCommand): (G: GameState) => boolean {
	return (G) =>
		pipe(
			O.of(G),
			O.chainFirst(moveInRange(moveCommand)),
			O.chainFirst(hasNotMoved(moveCommand)),
			O.fold(
				() => false,
				() => true
			)
		)
}

const hasNotMoved = (moveCommand: MoveUnitCommand) => (G: GameState) => {
	const { unitId } = moveCommand
	return pipe(
		G.playerMoves,
		PM.hasMoved(unitId),
		O.fromPredicate((a) => !a)
	)
}

function moveInRange(
	moveCommand: MoveUnitCommand
): (G: GameState) => O.Option<boolean> {
	const { unitId, to } = moveCommand
	const getUnit = unitById(unitId)
	return (G) =>
		pipe(
			O.Do,
			O.bind('unit', () => getUnit(G.units)),
			O.bind('from', (x) => coordForUnit(x.unit)(G.unitLocations)),
			O.bind('limit', ({ unit }) => O.some(unit.moveLimit)),
			O.bind('distance', ({ from }) => O.some(Cube.distance(from, to))),
			O.chain(({ distance, limit }) =>
				distance <= limit ? O.some(true) : O.none
			)
		)
}
function onRoundEnd(G: GameState): GameState {
	return {
		...G,
		roundInfo: RoundInfo.startRound(G.roundInfo),
	}
}
export default YearOfDecision

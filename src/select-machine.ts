import {
	createMachine,
	guard,
	invoke,
	transition,
	reduce,
	state,
	immediate,
} from 'robot3'
import { MoveUnitCommand } from './model/unit-location'
import { Cube } from './model/coords/cube'
import { Unit } from './model/unit'
import * as U from './model/unit'
import { Player, otherPlayer, toPlayer } from './model/player'
const wait = (delay: number) => () =>
	new Promise((resolve) => setTimeout(resolve, delay))

export interface Context {
	player: Player
	cube?: Cube
	unit?: Unit
	nextMove?: MoveUnitCommand
	previewMove?: MoveUnitCommand
	unitMission?: U.MissionType
}
export const initialContext = (a: Context): Context => ({
	...a,
	player: Player.UnionPlayer,
})

export enum States {
	Idle = 'idle',
	UnitSelected = 'unit-selected',
	UnitReady = 'unit-ready',
	MoveReady = 'move-ready',
	MissionReady = 'mission-ready',
	MissionSet = 'mission-set',
	Moving = 'moving',
	MoveMade = 'moved',
}
export enum ActionTypes {
	SelectUnit = 'select-unit',
	SelectCube = 'select-cube',
	MakeMove = 'make-move',
	SetMission = 'set-mission',
	MissionSet = 'mission-set',
	PreviewMove = 'preview-move',
	Switch = 'switch-players',
	Cancel = 'cancel',
}

export type SetMissionAction = {
	type: ActionTypes.SetMission
	mission: U.MissionType
}
export type SelectUnitAction = {
	type: ActionTypes.SelectUnit
	selected: Unit
}
export type SelectCubeAction = {
	type: ActionTypes.SelectUnit
	selected: Cube
}
export type PreviewMoveAction = {
	type: ActionTypes.PreviewMove
	selected: Cube
}
export type Action = SelectUnitAction | SelectCubeAction
export type SelectMachine = typeof machine

const selectUnit = transition(
	ActionTypes.SelectUnit,
	States.UnitReady,
	guard(canSelectUnit),
	reduce(onSelected)
)
const cancelSelection = transition(
	ActionTypes.SelectUnit,
	States.Idle,
	guard(isSelectedUnit),
	reduce(onCancel)
)

const assignMission = transition(
	ActionTypes.SetMission,
	States.MissionReady,
	reduce(onMissionSet)
)

export const machine = createMachine(
	States.Idle,
	{
		[States.Idle]: state(
			selectUnit,
			transition(ActionTypes.Switch, States.Idle, reduce(switchPlayer))
		),
		[States.UnitReady]: invoke(
			wait(150),
			transition('done', States.UnitSelected)
		),
		[States.UnitSelected]: state(
			transition(ActionTypes.Cancel, States.Idle, reduce(onCancel)),
			transition(
				ActionTypes.SelectCube,
				States.Moving,
				reduce(onCubeSelect)
			),
			cancelSelection,
			selectUnit,
			assignMission,
			transition(
				ActionTypes.PreviewMove,
				States.UnitSelected,
				reduce(onPreview)
			)
		),
		[States.Moving]: state(
			immediate(States.MoveReady, reduce(generateMove))
		),
		[States.MoveReady]: state(
			cancelSelection,
			transition(ActionTypes.MakeMove, States.MoveMade)
		),
		[States.MoveMade]: state(
			cancelSelection,
			transition(
				ActionTypes.SetMission,
				States.MissionReady,
				reduce(onMissionSet)
			)
		),
		[States.MissionReady]: state(
			transition(ActionTypes.MissionSet, States.Idle, reduce(reset))
		),
	},
	initialContext
)

function onCancel(ctx: Context): Context {
	return {
		...ctx,
		unit: undefined,
		previewMove: undefined,
	}
}
function onMissionSet(ctx: Context, event: SetMissionAction): Context {
	return {
		...ctx,
		unitMission: event.mission,
	}
}
function onPreview(ctx: Context, event: PreviewMoveAction): Context {
	const { unit } = ctx
	if (!unit) return ctx
	const { selected } = event
	return {
		...ctx,
		previewMove: { unitId: unit.unitId, to: selected },
	}
}
function resetMove({ player, unit }: Context): Context {
	return {
		player,
		unit,
	}
}
function reset(ctx: Context): Context {
	return {
		player: ctx.player,
	}
}
function switchPlayer(ctx: Context) {
	return {
		player: otherPlayer(ctx.player),
	}
}
function onSelected(ctx: Context, event: SelectUnitAction): Context {
	return {
		...ctx,
		unit: event.selected,
	}
}
function canSelectUnit(ctx: Context, event: SelectUnitAction): boolean {
	const { selected } = event
	const { player } = ctx
	return selected.player === player
}

function isSelectedUnit(ctx: Context, event: SelectUnitAction): boolean {
	const { selected } = event
	return (ctx.unit && U.Eq.equals(selected, ctx.unit)) || false
}

function onCubeSelect(ctx: Context, event: SelectCubeAction) {
	const { selected } = event
	return { ...ctx, cube: selected }
}

function generateMove(ctx: Context): Context {
	const { cube, unit } = ctx
	if (!cube || !unit) return ctx
	const nextMove = {
		unitId: unit.unitId,
		to: cube,
	}
	return { unit, player: ctx.player, nextMove }
}

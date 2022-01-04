import { Player } from 'model/player'
import * as Unit from 'model/unit'
import * as Combat from 'model/combat'
import { flow, pipe } from 'fp-ts/lib/function'
import * as A from 'fp-ts/Array'
import {
	createMachine,
	guard,
	invoke,
	transition,
	reduce,
	state,
	state as final,
	immediate,
} from 'robot3'

export interface Context {
	attacker: Player
	units: Unit.GameInfo[]
	commander: Unit.GameInfo
	commanded: Unit.GameInfo[]
	strategy: Combat.Strategy
	attackType: Combat.AttackType
	attackCommand?: Combat.AttackCommand
}

export enum States {
	Idle = 'idle',
	Ready = 'ready',
}

export const initialContext = (a: Context): Context => ({
	...a,
	strategy: a.strategy || Combat.Strategy.Regular,
	units: pipe(
		a.units,
		A.filter((unit) => unit.player === a.attacker)
	),
})

export enum ActionTypes {
	ChooseCommander = 'choose-commander',
	AddCommandedUnit = 'add-commanded-units',
	SetAttackType = 'set-attack-type',
	ChooseUnit = 'choose-unit',
	SaveAttackCommands = 'save',
	SetStrategy = 'set-strategy',
	Reset = 'reset',
}
export interface ChooseCommander {
	type: ActionTypes.ChooseCommander
	selected: Unit.GameInfo
}
export interface AddCommandedUnit {
	type: ActionTypes.AddCommandedUnit
	selected: Unit.GameInfo
}
export interface ChooseUnit {
	type: ActionTypes.ChooseUnit
	selected: Unit.GameInfo
}
export interface SetAttackType {
	type: ActionTypes.SetAttackType
	attackType: Combat.AttackType
}
export interface SetStrategy {
	type: ActionTypes.SetStrategy
	strategy: Combat.Strategy
}
export type Actions =
	| AddCommandedUnit
	| ChooseCommander
	| SetAttackType
	| ChooseUnit
export const machine = createMachine(
	States.Idle,
	{
		[States.Idle]: state(
			transition(
				ActionTypes.SetStrategy,
				States.Idle,
				reduce(onSetStrategy)
			),
			transition(
				ActionTypes.ChooseUnit,
				States.Idle,
				guard(canAddUnit),
				reduce(onAddCommanded)
			),
			transition(
				ActionTypes.SetAttackType,
				States.Idle,
				reduce(onSetAttackType2)
			),
			transition(
				ActionTypes.SaveAttackCommands,
				States.Ready,
				reduce(onSave)
			)
		),
		[States.Ready]: state(transition(ActionTypes.Reset, States.Idle)),
	},
	initialContext
)

function isPlayerUnit(
	ctx: Context,
	event: ChooseCommander | AddCommandedUnit
): boolean {
	return event.selected.player == ctx.attacker
}

function isWithinCommandSpan(ctx: Context): boolean {
	const span = ctx.commander?._tag === 'HQ' ? ctx.commander.commandSpan : 0
	return ctx.commanded.length < span
}

function onChooseCommander(
	ctx: Context,
	{ selected }: ChooseCommander
): Context {
	return {
		...ctx,
		commander: selected,
		units: pipe(
			ctx.units,
			A.filter((a) => !Unit.Eq.equals(selected, a))
		),
	}
}

function onAddCommanded(ctx: Context, { selected }: AddCommandedUnit): Context {
	return {
		...ctx,
		commanded: [...ctx.commanded, selected],
		units: pipe(
			ctx.units,
			A.filter((a) => !Unit.Eq.equals(selected, a))
		),
	}
}

function onSetStrategy(ctx: Context, { strategy }: SetStrategy): Context {
	return {
		...ctx,
		strategy,
	}
}
function onSetAttackType2(
	ctx: Context,
	{ attackType }: SetAttackType
): Context {
	return {
		...ctx,
		attackType,
	}
}
function onSave(ctx: Context): Context {
	return {
		...ctx,
		attackCommand: {
			attackType: ctx.attackType,
			strategy: ctx.strategy,
			commander: ctx.commander,
			commanded: ctx.commanded,
		},
	}
}

export function makeChooseUnit(unit: Unit.GameInfo): ChooseUnit {
	return {
		type: ActionTypes.ChooseUnit,
		selected: unit,
	}
}
function canAddUnit(ctx: Context, event: AddCommandedUnit) {
	return isPlayerUnit(ctx, event) && isWithinCommandSpan(ctx)
}

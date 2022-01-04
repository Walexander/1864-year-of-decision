import { flow, pipe } from 'fp-ts/lib/function'
import * as A from 'fp-ts/Array'
import * as O from 'fp-ts/Option'
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
import * as GB from 'model/game-board'
import {Player} from 'model/player'
import * as Unit from 'model/unit'
import * as Combat from 'model/combat'
export interface Context {
	attacker: Player,
	units: Unit.GameInfo[]
	commander?: Unit.GameInfo
	commanded: Unit.GameInfo[]
	attackCommands: Combat.AttackCommand[]
	strategy: Combat.Strategy
	attackType: Combat.AttackType
	picked: Unit.GameInfo[]
}

export enum States {
	Idle = 'idle',
	CommanderReady = 'commander-ready',
	Saving = 'saving',
	Ready = 'done',
}

export const initialContext = (a: Context): Context => ({
	...a,
	strategy: a.strategy || Combat.Strategy.Regular,
	units: pipe(
		a.units,
		A.filter( (unit) => unit.player === a.attacker )
	),
	picked: [],
})

export enum ActionTypes {
	ChooseCommander = 'choose-commander',
	AddCommandedUnit = 'add-commanded-units',
	SetAttackType = 'set-attack-type',
	ChooseUnit = 'choose-unit',
	SaveAttackCommand = 'save',
	SetStrategy = 'set-strategy',
	Reset  = 'reset'
}
export interface ChooseCommander {
	type: ActionTypes.ChooseCommander
	selected: Unit.GameInfo
}
export interface SaveAttackCommand {
	type: ActionTypes.SaveAttackCommand
	command: Combat.AttackCommand
}
export type Actions = ChooseCommander | SaveAttackCommand 
export const machine = createMachine(
	States.Idle,
	{
		[States.Idle]: state(
			transition(
				ActionTypes.ChooseCommander,
				States.CommanderReady,
				guard(isPlayerUnit),
				reduce(onChooseCommander)
			),
			transition(
				ActionTypes.ChooseUnit,
				States.CommanderReady,
				guard(isPlayerUnit),
				reduce(onChooseCommander)
			)
		),
		[States.CommanderReady]: state(
			transition(
				ActionTypes.SaveAttackCommand,
				States.Saving,
				reduce(onSave)
			),
		),
		[States.Saving]: state(
			immediate(
				States.Idle,
				guard((ctx: Context) => ctx.units.length > 0),
			),
			immediate( States.Ready ),
		),
		[States.Ready]: state(),
	},
	initialContext
)

function isPlayerUnit(ctx: Context, event: ChooseCommander): boolean {
	return event.selected.player == ctx.attacker
}

function onChooseCommander(ctx: Context, {selected}: ChooseCommander): Context {
	return {
		...ctx,
		commander: selected,
		units: pipe(
			ctx.units,
			A.filter( (a) => !Unit.Eq.equals(selected, a) )
		)
	}
}

function onSave(ctx: Context, {command}: SaveAttackCommand) : Context {
	if(!ctx.commander)
		return ctx
	const units =  pipe(
		ctx.units,
		A.difference(Unit.InfoEq)(command.commanded)
	)
	return {
		...ctx,
		units: pipe(
			ctx.units,
			A.difference(Unit.InfoEq)(command.commanded)
		),
		attackCommands: [
			...ctx.attackCommands,
			command,
		]
	}
}

function onReset(ctx: Context): Context {
	return {
		attackType: Combat.AttackType.REGULAR,
		attacker: ctx.attacker,
		units: [],
		picked: [],
		attackCommands: [],
		commander: undefined,
		commanded: [],
		strategy: Combat.Strategy.Regular,
	}
}

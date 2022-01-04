import { flow, pipe, identity } from 'fp-ts/lib/function'
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
	Service,
	Machine,
} from 'robot3'
import * as GB from './model/game-board'
import { machine as planMachine } from 'Combat/plan-machine'
import { machine as simpleMachine } from 'Combat/simple-machine'
import { Player } from './model/player'
import * as Unit from './model/unit'
import * as Combat from './model/combat'

declare module 'robot3' {
	interface Service<M extends Machine> {
		child: M
	}
}
export enum States {
	Idle = 'idle',
	Plan = 'planAttack',
	Muster = 'musterTroops',
	Charge = 'charge',
}

export interface Context {
	attacker: Player
	units: Unit.GameInfo[]
	attackCommands: Combat.AttackCommand[]
	picked: Unit.GameInfo[]
}

export const initialContext = (a: Context): Context => ({
	...a,
	units: pipe(
		a.units,
		A.filter((unit) => unit.player === a.attacker)
	),
	picked: [],
})

export enum ActionTypes {
	Begin = 'begin',
	SaveAttackCommand = 'saveAttackCommand',
	StartMuster = 'musterTroops',
	Reset = 'reset',
}
export interface Begin {
	type: ActionTypes.Begin
}
export interface SaveOrders {
	type: ActionTypes.SaveAttackCommand
	orders: Combat.AttackCommand[]
}
export interface StartMuster {
	type: ActionTypes.StartMuster
}
export type Actions = Begin | SaveOrders | StartMuster
export const machine = createMachine(
	States.Plan,
	{
		[States.Idle]: state(transition(ActionTypes.Begin, States.Plan)),
		[States.Plan]: state(
			transition(
				ActionTypes.SaveAttackCommand,
				States.Plan,
				reduce(onSave)
			),
			transition(ActionTypes.StartMuster, States.Muster)
		),
		[States.Muster]: state(),
		[States.Charge]: state(),
	},
	initialContext
)

function onSave(ctx: Context, { orders }: SaveOrders): Context {
	return {
		...ctx,
		attackCommands: [...ctx.attackCommands, ...orders],
	}
}
export interface ServiceMachine {
	name: States
	context: Context
}

export function fold<A>(
	onIdle: (ctx: Context) => A,
	onPlan: (ctx: Context) => A,
	onMuster: (ctx: Context) => A,
	onCharge: (ctx: Context) => A
): (service: ServiceMachine) => A {
	return (service) => {
		const ctx = service.context
		switch (service.name) {
			case States.Idle:
				return onIdle(ctx)
			case States.Plan:
				return onPlan(ctx)
			case States.Muster:
				return onMuster(ctx)
			case States.Charge:
				return onCharge(ctx)
		}
	}
}

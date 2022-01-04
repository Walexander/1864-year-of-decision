import { createMachine, transition, immediate, guard, state } from 'robot3'
import { Unit } from './unit'
export enum States {
	InSupply = 'in-supply',
	Broken1 = 'broken-1',
	Broken2 = 'broken-2',
	Reduced = 'reduced',
	OutOfSupply = 'out',
}

export enum ActionTypes {
	Tick = 'tick',
}

export interface Context {
	unit: Unit
}

interface TickAction {
	type: ActionTypes.Tick
	supplied: boolean
}

export type Actions = TickAction

const resupply = transition(ActionTypes.Tick, States.InSupply, guard(hasSupply))

export const machine = createMachine(
	States.InSupply,
	{
		[States.InSupply]: state(
			transition(ActionTypes.Tick, States.Broken1, guard(noSupply))
		),
		[States.Broken1]: state(
			resupply,
			transition(ActionTypes.Tick, States.Broken2, guard(noSupply))
		),
		[States.Broken2]: state(
			resupply,
			transition(ActionTypes.Tick, States.Reduced, guard(noSupply))
		),
		[States.Reduced]: state(),
		[States.OutOfSupply]: state(),
	},
	init
)

function hasSupply(_: Context, event: TickAction): boolean {
	return event.supplied
}
function noSupply(_: Context, event: TickAction): boolean {
	return !event.supplied
}

function init(ctx: Context) {
	return {
		...ctx,
	}
}

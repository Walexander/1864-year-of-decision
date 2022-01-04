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
import { identity } from 'fp-ts/function'
import { Context as ParentContext } from '../combat-machine'

const wait = (delay: number) => () =>
	new Promise((resolve) => setTimeout(resolve, delay))

export const machine = createMachine({
	idle: state(transition('finish', 'waiting')),
	end: final(),
})

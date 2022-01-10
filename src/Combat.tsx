import React from 'react'
import styled from 'styled-components'
import { match , select } from 'ts-pattern'
import { identity, pipe } from 'fp-ts/function'
import { useMachine } from 'react-robot'
import { machine, fold, States } from './combat-machine'
import * as O from 'fp-ts/Option'
import * as M from 'combat-machine'
import { GameMoves }  from 'Game'
import * as U from './model/unit'
import * as C from './model/combat'
import { GameState } from 'game-state'
import {Player, otherPlayer} from './model/player'
import { Muster  } from 'Combat/Muster'
import { PlanAttack } from 'Combat/PlanAttack'
import { Calculate } from 'Combat/Calculate'
import { CombatStage } from 'Game'
import { RollResult } from 'Combat/RollResult'
import {Crank} from 'Crank'
export interface PropTypes {
	units: U.GameInfo[]
	onReady: Function
	stage: CombatStage
	G: GameState,
	moves: GameMoves,
	attacker: Player
}

function fold2<A>(
	onPlan: () => A,
	onMuster: () => A,
	onCalculate: () => A,
	onCharge: () => A,
	onDefault: () => A
): (stage: CombatStage) => A {
	return (stage) => {
		switch(stage) {
			case(CombatStage.Plan):
				return onPlan()
			case(CombatStage.Muster):
				return onMuster()
			case(CombatStage.Calculate):
				return onCalculate()
			case(CombatStage.Charge):
				return onCharge()
			default:
				return onDefault()
		}
	}
}
export const Combat: React.FC<PropTypes> = ({
	G,
	moves,
	onReady,
	units,
	stage,
	attacker,
}) => {
	const [combatMachine, sendMachine] = useMachine(machine, {
		units,
		picked: [],
		attacker,
		attackCommands: G.attackPlans,
	})
	const { units: availableUnits, attackCommands } = combatMachine.context
	const { musterNext, surveyConflict, rollFor, tacticalRoll } = moves
	const getCalculate = () => (
		<Calculate
			startCharge={
				stage === CombatStage.Charge
					? moves.combatRoll
					: moves.startCharge
			}
			stage={stage}
			attacker={attacker}
			modifiers={G.modifiers}
			tacticalRoll={G.tacticalRoll}
			defender={otherPlayer(attacker)}
			onRoll={tacticalRoll}
			combatResults={G.combat.result}
			attackers={G.attackers}
			defenders={pipe(
				G.combatCell,
				O.fromNullable,
				O.map((cell) => C.getDefender(cell, attacker)(G)),
				O.fold(() => [], identity)
			)}
		>
			{stage === CombatStage.Calculate ? (
				<Crank onClick={() => moves.startCharge()}>Attack!</Crank>
			) : (
				<>
					<Crank onClick={() => moves.surveyConflict()}>
						Finish!
					</Crank>
					<RollResult combat={G.combat} />
				</>
			)}
		</Calculate>
	)
	const component = fold2(
		() => (
			<PlanAttack
				units={availableUnits}
				stage={stage}
				attacker={attacker}
				onReady={() => {
					sendMachine({
						type: M.ActionTypes.StartMuster,
					})
					onReady(attackCommands)
				}}
				onSave={(orders: C.AttackCommand[]) => {
					sendMachine({
						type: M.ActionTypes.SaveAttackCommand,
						orders,
					})
				}}
			/>
		),
		() => (
			<>
				<h2> Mustering </h2>
				<button
					disabled={!!G.nextOrder && !G.musterResult}
					onClick={() => musterNext()}
				>
					Next
				</button>
				{G.nextOrder ? (
					<Muster
						status={G.musterResult}
						attacking={G.attackers}
						onRoll={() => rollFor()}
						roll={G.lastRoll}
						next={G.nextOrder}
						orders={G.attackPlans}
					/>
				) : null}
			</>
		),
		getCalculate,
		getCalculate,
		() => <h1>never!</h1>
	)

	return <Wrapper>
		{component(stage)}
	</Wrapper>
}


export const Wrapper = styled.main`
	color: white;
	background: darkgrey;
	min-width: 12rem;
	margin: auto;
	z-index: 2;
	padding: 0.5rem;
	position: absolute;
	left: 1rem;
	top: 12rem;
`

import React from 'react'
import * as M from 'fp-ts/Monoid'
import * as N from 'fp-ts/number'
import {pipe} from 'fp-ts/function'
import styled from 'styled-components'
import { SVGChit } from 'Chit/Token'
import { Player } from 'model/player'
import { Crank } from 'Crank'
import { ModTracker } from 'Combat/ModTracker'
import * as U from 'model/unit'
import * as C from 'model/combat'
import * as A from 'fp-ts/Array'
import {CombatModifiers} from 'game-state'
import {CombatStage} from 'Game'
import{ BattleResult}from 'model/combat/result'
import {CombatResult} from './Result'

export interface PropTypes {
	stage: CombatStage
	attackers: C.AttackCommand[]
	defenders: U.GameInfo[]
	attacker: Player
	defender: Player
	onRoll: Function
	startCharge: Function
	modifiers: CombatModifiers
	modifier: number
	tacticalRoll: [number, number]
	children?: React.ReactChild
	combatResults?: BattleResult
}

export const Calculate: React.FC<PropTypes> = ({
	attackers,
	defender,
	defenders,
	attacker,
	tacticalRoll,
	modifiers,
	modifier,
	onRoll,
	children,
	combatResults,
}) => {
	const attackingUnits = pipe(
			attackers,A.map( (a) => a.commander )
	)
	const [attackerRoll ] = tacticalRoll
	const attackerSp = pipe(
		attackingUnits,
		C.getStrengthPoints
	)
	const attackerCommander = pipe(
		attackingUnits,
		C.getCommander
	)
	const defenderSp = pipe(defenders, C.getStrengthPoints)
	const defendingCommander = pipe(
		defenders,
		C.getCommander
	)
	const ratio = C.getRatio(attackerSp, defenderSp)
	return (
		<Wrapper className={'--' + attacker.toLowerCase()}>
			combat ratio<h1>{ratio}</h1>
			<BattleField className={'--' + attacker.toLowerCase()}>
				<div>
					<h3>{attacker}</h3>
					<h4>{attackerSp}</h4>(sp)
					<h4>{attackerCommander.unitId}</h4>
				</div>
				<ChitList>
					{attackers.map((command) => (
						<li
							className={
								U.Eq.equals(
									command.commander,
									attackerCommander
								)
									? '--commander'
									: ''
							}
						>
							<SVGChit unit={command.commander} />
							<h4>{command.attackType}</h4>
						</li>
					))}
				</ChitList>
				<div>
				{!combatResults ?  null : <>
					<CombatResult results={combatResults.attacker} />
				</>}
				</div>
			</BattleField>
			<BattleField className={'--' + defender.toLowerCase()}>
				<div>
					<h3>{defender}</h3>
					<h4>{defenderSp}</h4>(sp)
					<h4>{defendingCommander.unitId}</h4>
				</div>
				<ChitList>
					{defenders.map((unit) => (
						<li
							className={
								U.Eq.equals(unit, defendingCommander)
									? '--commander'
									: ''
							}
						>
							<SVGChit unit={unit} />
							<h4> DEFENDING </h4>
						</li>
					))}
				</ChitList>
				<div>
				{!combatResults ?  null : <>
					<CombatResult results={combatResults.defender} />
				</>}
				</div>
			</BattleField>
			<aside>
				<h2>Roll Modifications</h2>
				<ModifierList
					attackerRoll={attackerRoll}
					onRoll={onRoll}
					modifiers={modifiers}
				/>
				<ModTracker range={10} value={modifier} />
				{ children }
			</aside>
		</Wrapper>
	)
}

interface ModifierProps {
	attackerRoll: number
	onRoll: Function
	modifiers: CombatModifiers,
}

const ModifierList: React.FC<ModifierProps> = ({
	attackerRoll,
	onRoll,
	modifiers,
}) => (
	<ModWrapper>
		{pipe(
			Object.entries(modifiers),
			A.map(([key, modifier]) => (
				<div>
					{key}
					{
						key === 'tactical' && attackerRoll == 0 ?
						<div><Crank onClick={() => onRoll()}>Roll</Crank></div>
						: <h1>{modifier}</h1>
					}
					
				</div>
			))
		)}
	</ModWrapper>
)
const ModWrapper = styled.div`
	display: flex;
	flex-direction: row;
	column-gap: 1rem;
	justify-content: space-around;
`
const ChitList = styled.ul`
	list-style: none;
	display: flex;
	column-gap: 0.5rem;
	padding: 2rem;
	justify-content: center;
	color: inherit;
	button {
		color: inherit;
	}
	li {
		position: relative;
	}
	li.--commander::before {
		background: darkred;
		display: block;
		content: 'Commander';
		position: absolute;
		left: 0;
		top: 0;
		right: 0;
		transform: translateY(-100%);
	}
`
export const Wrapper = styled.div`
	display: grid;
	background: darkred;
	row-gap: 0.25rem;
	min-width: 800px;

	aside {
		background: darkgrey;
	}
`

export const BattleField = styled.div`
	display: grid;
	background: var(--accent);
	grid-template-columns: 200px 1fr 150px;
	column-gap: 0.25rem;
	> * {
		background: var(--contrast);
	}
	> div {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
	}
`

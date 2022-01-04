import React from 'react'
import styled from 'styled-components'
import { Crank } from 'Crank'
import * as C from 'model/combat'
import * as U from 'model/unit'
import {SVGChit} from 'Chit/Token'

export interface PropTypes {
	orders: C.AttackCommand[]
	attacking?: C.AttackCommand[]
	status: string
	onRoll: Function
	next?: C.AttackCommand
	roll?: number
}
export const Wrapper = styled.div`
	position: relative;
`

export const Muster: React.FC<PropTypes> = ({ attacking = [], status, onRoll, roll, next, orders }) => (
	<Wrapper>
		{next ? (
			<CurrentOrder
				status={status}
				roll={roll || 0}
				order={next}
				onRoll={() => onRoll()}
			/>
		) : null}
		<hr/>
		<h2> Pending </h2>
		<ul>
			{orders.map((a) => (
				<li>
					{a.commander.unitId} ({a.attackType})
					<ol>
						{a.commanded.map((u) => (
							<li>{u.unitId}</li>
						))}
					</ol>
				</li>
			))}
		</ul>
		<hr/>
		<h2> Cut The Muster </h2>
		<ul>
			{attacking.map((a) => (
				<li>
					{a.commander.unitId} ({a.attackType})
					<ol>
						{a.commanded.map((u) => (
							<li>{u.unitId}</li>
						))}
					</ol>
				</li>
			))}
		</ul>
	</Wrapper>
)

const CurrentOrder: React.FC<{
	roll?: number
	status: string
	onRoll: Function
	order: C.AttackCommand
}> = ({ order, status, roll, onRoll }) => {
	const { commander } = order
	return (
		<CurrWrapper className={'--' + status}>
			<SVGChit unit={commander} />
			<h2>Roll needed: {C.minRoll(order)}</h2>
			{roll ? (
				<h2>{roll}</h2>
			) : (
				<Crank style={{display: 'block'}} onClick={() => onRoll()}>Roll</Crank>
			)}
		</CurrWrapper>
	)
}

const CurrWrapper = styled.div`
	position: relative;
	&::after {
		content: var(--overlay, inherit);
		background: var(--bg, transparent);
		opacity: 0.5;
		position: absolute;
		top: 0;
		left: 0;
		bottom: 0;
		right: 0;
	}
	&::before {
		content: var(--txt, inherit);
		position: relative;
		z-index: 1;
		display: block;
		font-size: 2rem;
	}
	&.--success {
		--bg: green;
		--txt: 'success';
		--overlay: '';
		&::before {
			color: darkblue;
		}
	}
	&.--failed {
		--bg: red;
		--overlay: '';
		--txt: 'failed';
	}
`


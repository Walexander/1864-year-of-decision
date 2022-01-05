
import React from 'react'
import styled from 'styled-components'
import {GameState} from 'game-state'
export interface PropTypes {
	combat: GameState['combat']
}

export const RollResult: React.FC<PropTypes> = ({ combat }) => (
	<>
		<h1>Combat Results</h1>
		<h5>Roll + Modifier = Effective</h5>
		<Wrapper>
			<div>
				<h3>Roll</h3>
				<h1>{combat.roll}</h1>
			</div>
			<div>
				<h3>Modifier</h3>{' '}
				<h1>
					{combat.modifier > 0 ? '+' : ''}
					{combat.modifier}
				</h1>
			</div>
			<div style={{ color: 'red' }}>
				<h3>Effective</h3> <h1>{combat.roll + combat.modifier}</h1>
			</div>
		</Wrapper>
	</>
)

export const Wrapper = styled.div`
	display: flex;
	column-gap: 1rem;
	justify-content: center;
	align-items: center;
	> * {
		flex-grow: 1;
		padding: 0.25rem;
		border: 1px solid black;
	}
`

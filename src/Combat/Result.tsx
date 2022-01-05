import React from 'react'
import styled from 'styled-components'
import { Result } from 'model/combat/result'
export interface PropTypes {
	results: Result
}

export const CombatResult: React.FC<PropTypes> = ({ results }) => (
	<>
		<Wrapper>
			<div>
				<h3>{results.loss * 100 + '%'} Lost</h3>
			</div>
			<div>
				<h3>{results.pows} POW's</h3>
			</div>
			<div>
			<h6>Routed?</h6>
			<h3 style={{color: results.routed ? 'red': 'green'}}>
				{results.routed ? 'ROUTED' : 'NO'}
			</h3>
			</div>
		</Wrapper>
	</>
)

export const Wrapper = styled.div`
	display: flex;
	flex-direction: column;
	row-gap: 0.25rem;
	justify-content: center;
	align-items: center;
	> * {
		flex-grow: 1;
		padding: 0.25rem;
	}
`

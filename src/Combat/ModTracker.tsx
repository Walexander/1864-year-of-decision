import * as React from 'react'
import * as A from 'fp-ts/Array'
import {pipe} from 'fp-ts/function'

import styled from 'styled-components'

interface PropTypes {
	range: number
	value: number
}

export const ModTracker: React.FC<PropTypes> = ({ range, value }) => (
	<Wrapper>
		{pipe(
			A.makeBy(range + 1, (i) => i - range / 2 + (range % 2)),
			A.map((mod) => <li>{mod}
				{mod === value ? <Marker /> : null}
			</li>)
		)}
	</Wrapper>
)

export const Wrapper = styled.ul`
	display: grid;
	width: 100%;
	row-gap: 0.5rem;
	column-gap: 0.5rem;
	list-style: none;
	padding: 0.25rem;
	background: black;
	grid-template-columns: repeat(11, 1fr);
	color: black;
	align-items:center;
	> li {
		position: relative;
		font-size: 2.75rem;
		flex-grow: 1;
		font-weight: boldest;
		color: yellow;
		background: lightgrey;;
		aspect-ratio: 1/1;
		display: flex;
		align-items: center;
		justify-content: center;
	}
`

const Marker = styled.div`
	border: 1px solid black;
	position: absolute;
	opacity: 0.8;
	background: black;
	left: 20%;
	right: 20%;
	top: 10%;
	bottom: 30%;
	display: flex;
	align-items: center;
	justify-content: center;
	&::before {
		font-size: 1.5rem;
		font-weight: 900;
		color: white;
		content: 'M';
		left: 50%;
	}
`

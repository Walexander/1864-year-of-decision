import React from 'react'
import styled from 'styled-components'
import * as A from 'fp-ts/Array'
import { pipe  } from 'fp-ts/function'
import * as U from '../model/unit'
import { SVGChit } from '../Chit/Token'

interface SelectedUnitProps {
	unit: U.GameInfo
	commanded: U.GameInfo[]
}

export const AttackCommandMenu: React.FC<SelectedUnitProps> = (props) => {
	return (
		<SelectedUnitWrapper>
			<h4>Commander:</h4>
			<SVGChit unit={props.unit} />
			<CommandedItemList>
				{pipe(
					props.commanded,
					A.map((unit) => (
						<Item key={unit.unitId}>
							<SVGChit unit={unit} />
						</Item>
					))
				)}
			</CommandedItemList>
		</SelectedUnitWrapper>
	)
}

const SelectedUnitWrapper = styled.main`
	top: 1rem;
	left: 1rem;
`
const CommandedItemList = styled.ul`
	list-style-type: none;
	display: grid;
	grid-template-columns: 1fr 1fr;
	row-gap: 0.5rem;
	column-gap: 0.5rem;
	padding: 0.5rem;
`
const Item = styled.li`
	cursor: pointer;
	svg {
		width: 100%;
		height: auto;
	}
`

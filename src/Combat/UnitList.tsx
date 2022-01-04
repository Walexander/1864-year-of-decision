import React from 'react'
import * as A from 'fp-ts/Array'
import styled from 'styled-components'
import * as U from 'model/unit'
import { SVGChit } from 'Chit/Token'
import {pipe} from 'fp-ts/lib/function'
export const UnitList: React.FC<{ units: U.GameInfo[]; onClick: Function }> = (
	props
) => {
	const units = pipe(
		props.units,
		A.sort(U.Ord),
		A.reverse,
	)
	return (
		<AvailableItemList>
			{units.map((unit) => (
				<UnitItem unit={unit} onClick={() => props.onClick(unit)} />
			))}
		</AvailableItemList>
	)
}

const UnitItem: React.FC<{unit: U.GameInfo; onClick: Function }> = ({
	onClick,
	unit,
}) => {
	return <Item onClick={() => onClick()}>
		<SVGChit unit={unit} />
	</Item>
}
const AvailableItemList = styled.ul`
	list-style-type: none;
	padding: 0;
	display: grid;
	column-gap: 1rem;
	row-gap: 1rem;
	grid-template-columns: repeat(auto-fit, 5rem);
	justify-content: center;
`

const Item = styled.li`
	cursor: pointer;
	svg {
		width: 100%;
		height: auto;
	}
`

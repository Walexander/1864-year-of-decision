import React from 'react'
import styled from 'styled-components'
import { pipe, flow  } from 'fp-ts/function'
import { not  } from 'fp-ts/Predicate'
import * as M from '../combat-machine'
import * as U from 'model/unit'
import { Crank } from 'Crank'
import * as C from 'model/combat'
import { SVGChit  } from 'Chit/Token'

export interface PropTypes {
	orders: C.AttackCommand[]
}

export const Picked: React.FC<PropTypes> = ({ orders }) => (
	<>
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
	</>
)

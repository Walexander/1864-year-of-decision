import { findClosestT } from '../combat'
import { pipe } from 'fp-ts/function'
import * as U from 'model/unit'
import { GameState } from '../../game-state'

/* 
 * [ 
 *   [ratio, [
 *		[roll, Result],
 *		[roll, Result]
 *   ]]
 * ]
* */
export interface Result {
	loss: number,
	pows: number,
	routed: boolean
}

export interface BattleResult {
	attacker: Result,
	defender: Result
}
type Roll = number
type Ratio = number
type ResultRow = Array<[Roll, BattleResult]>
type ResultTable = Array<[Ratio, ResultRow]>

const resultTable: ResultTable = [
	[0.75, [
		[-2,  {
			attacker: { loss: 0.2, routed: true, pows: 0 },
			defender: { loss: 0.03, routed: false, pows: 0 }
		}],
		[-1,  {
			attacker: { loss: 0.18, routed: true, pows: 0 },
			defender: { loss: 0.03, routed: false, pows: 0 }
		}],
		[0,  {
			attacker: { loss: 0.18, routed: true, pows: 0 },
			defender: { loss: 0.05, routed: false, pows: 0 }
		}],
		[1,  {
			attacker: { loss: 0.18, routed: false, pows: 2 },
			defender: { loss: 0.06, routed: false, pows: 0 }
		}],
		[2,  {
			attacker: { loss: 0.15, routed: false, pows: 1 },
			defender: { loss: 0.06, routed: false, pows: 0 }
		}],
		[3,  {
			attacker: { loss: 0.15, routed: false, pows: 0 },
			defender: { loss: 0.06, routed: false, pows: 0 }
		}],
		[4,  {
			attacker: { loss: 0.15, routed: false, pows: 0 },
			defender: { loss: 0.08, routed: false, pows: 0 }
		}],
		[5,  {
			attacker: { loss: 0.12, routed: false, pows: 0 },
			defender: { loss: 0.06, routed: false, pows: 0 }
		}],
		[6,  {
			attacker: { loss: 0.12, routed: false, pows: 0 },
			defender: { loss: 0.06, routed: false, pows: 0 }
		}],
		[7,  {
			attacker: { loss: 0.12, routed: false, pows: 0 },
			defender: { loss: 0.08, routed: false, pows: 1 }
		}],
		[8,  {
			attacker: { loss: 0.12, routed: false, pows: 0 },
			defender: { loss: 0.08, routed: false, pows: 2 }
		}],
		[9,  {
			attacker: { loss: 0.12, routed: false, pows: 0 },
			defender: { loss: 0.10, routed: false, pows: 3 }
		}],
	]],
	[1.00, [
		[-2,  {
			attacker: { loss: 0.15, routed: true, pows: 0 },
			defender: { loss: 0.03, routed: false, pows: 0 }
		}],
		[-1,  {
			attacker: { loss: 0.15, routed: true, pows: 0 },
			defender: { loss: 0.05, routed: false, pows: 0 }
		}],
		[0,  {
			attacker: { loss: 0.15, routed: false, pows: 2 },
			defender: { loss: 0.06, routed: false, pows: 0 }
		}],
		[1,  {
			attacker: { loss: 0.10, routed: false, pows: 1 },
			defender: { loss: 0.05, routed: false, pows: 0 }
		}],
		[2,  {
			attacker: { loss: 0.10, routed: false, pows: 0 },
			defender: { loss: 0.06, routed: false, pows: 0 }
		}],
		[3,  {
			attacker: { loss: 0.08, routed: false, pows: 0 },
			defender: { loss: 0.04, routed: false, pows: 0 }
		}],
		[4,  {
			attacker: { loss: 0.08, routed: false, pows: 0 },
			defender: { loss: 0.05, routed: false, pows: 0 }
		}],
		[5,  {
			attacker: { loss: 0.06, routed: false, pows: 0 },
			defender: { loss: 0.05, routed: false, pows: 1 }
		}],
		[6,  {
			attacker: { loss: 0.06, routed: false, pows: 0 },
			defender: { loss: 0.06, routed: false, pows: 1 }
		}],
		[7,  {
			attacker: { loss: 0.06, routed: false, pows: 0 },
			defender: { loss: 0.06, routed: false, pows: 1 }
		}],
		[8,  {
			attacker: { loss: 0.06, routed: false, pows: 0 },
			defender: { loss: 0.08, routed: false, pows: 2 }
		}],
		[9,  {
			attacker: { loss: 0.06, routed: false, pows: 0 },
			defender: { loss: 0.10, routed: true, pows: 0 }
		}],
	]],
	[2.50, [
		[-2,  {
			attacker: { loss: 0.06, routed: false, pows: 2 },
			defender: { loss: 0.05, routed: false, pows: 0 }
		}],
		[-1,  {
			attacker: { loss: 0.06, routed: false, pows: 1 },
			defender: { loss: 0.06, routed: false, pows: 0 }
		}],
		[0,  {
			attacker: { loss: 0.06, routed: false, pows: 0 },
			defender: { loss: 0.08, routed: false, pows: 0 }
		}],
		[1,  {
			attacker: { loss: 0.05, routed: false, pows: 0 },
			defender: { loss: 0.08, routed: false, pows: 0 }
		}],
		[2,  {
			attacker: { loss: 0.05, routed: false, pows: 0 },
			defender: { loss: 0.10, routed: false, pows: 1 }
		}],
		[3,  {
			attacker: { loss: 0.04, routed: false, pows: 0 },
			defender: { loss: 0.08, routed: false, pows: 2 }
		}],
		[4,  {
			attacker: { loss: 0.04, routed: false, pows: 0 },
			defender: { loss: 0.10, routed: false, pows: 3 }
		}],
		[5,  {
			attacker: { loss: 0.04, routed: false, pows: 0 },
			defender: { loss: 0.10, routed: false, pows: 4 }
		}],
		[6,  {
			attacker: { loss: 0.04, routed: false, pows: 0 },
			defender: { loss: 0.12, routed: true, pows: 0 }
		}],
		[7,  {
			attacker: { loss: 0.05, routed: false, pows: 0 },
			defender: { loss: 0.15, routed: true, pows: 0 }
		}],
		[8,  {
			attacker: { loss: 0.04, routed: false, pows: 0 },
			defender: { loss: 0.18, routed: true, pows: 0 }
		}],
		[9,  {
			attacker: { loss: 0.04, routed: false, pows: 0 },
			defender: { loss: 0.20, routed: true, pows: 0 }
		}],
	]],
]

export function getCombatResult(
	combatOdds: number
): (roll: number) => BattleResult {
	const getColumn = findClosestT<ResultRow>(resultTable)
	const column = getColumn(combatOdds)
	const getRow = findClosestT<BattleResult>(column)
	return getRow
}

export interface RoundInfo {
	round: number
	date: number
	weather: number
}

export function RoundInfo(
	round: number,
	date: number,
	weather: number
): RoundInfo {
	return { round, date, weather }
}

export function startRound(info: RoundInfo): RoundInfo {
	return {
		round: info.round + 1,
		weather: 3,
		date: info.date + 86400e3 * 3,
	}
}

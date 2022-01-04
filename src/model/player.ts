export enum Player {
	UnionPlayer = 'UnionPlayer',
	CSAPlayer = 'CSAPlayer',
}
export function toPlayer(id: string): Player {
	return id === '0' ? Player.UnionPlayer : Player.CSAPlayer
}

export function otherPlayer(current: Player): Player {
	return Player.CSAPlayer === current ? Player.UnionPlayer : Player.CSAPlayer
}

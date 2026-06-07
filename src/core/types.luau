--[[
	@name types
	@author dullflowerr
	@time June 7, 2026
]]

export type Tone = "trace" | "phase" | "success" | "warn" | "error"
export type Fields = { [string]: any }

export type Event = {
	tone: Tone?,
	scope: string?,
	action: string?,
	fields: Fields?,
	key: string?,
	duration: number?,
	sticky: boolean?,
	liveInterval: number?,
}

export type Token = {
	scope: string,
	action: string,
	started: number,
}

export type GraphOptions = {
	tone: Tone?,
	style: "bars"?,
	unit: string?,
	range: { number }?,
	warnAt: number?,
	failAt: number?,
	format: ((number) -> any)?,
}

export type GraphHandle = {
	push: (self: GraphHandle, value: number) -> (),
	rescale: (self: GraphHandle, factor: number) -> (),
	remove: (self: GraphHandle) -> (),
}

export type Provider = {
	id: string,
	start: (self: Provider, client: any) -> (),
	stop: (self: Provider) -> (),
}

export type Template = {
	id: string,
	monitorRows: number,
	providers: { Provider },
}

return {}

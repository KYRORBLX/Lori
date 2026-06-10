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
	warnBelow: number?,
	failBelow: number?,
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

export type Theme = { [string]: Color3 }

export type ClientOptions = {
	config: { [string]: any }?,
	template: any?,
	templateBlacklist: any?,
	theme: Theme?,
	[string]: any,
}

export type WatchOptions = {
	interval: number?,
	action: string?,
	scope: string?,
	tone: Tone?,
}

export type Watch = {
	connected: boolean,
	disconnect: (self: Watch) -> (),
}

export type Channel = {
	trace: (self: Channel, action: string?, fields: Fields?, duration: number?) -> (),
	info: (self: Channel, action: string?, fields: Fields?, duration: number?) -> (),
	phase: (self: Channel, action: string?, fields: Fields?, duration: number?) -> (),
	success: (self: Channel, action: string?, fields: Fields?, duration: number?) -> (),
	warn: (self: Channel, action: string?, fields: Fields?, duration: number?) -> (),
	fail: (self: Channel, action: string?, fields: Fields?, duration: number?) -> (),
	error: (self: Channel, action: string?, fields: Fields?, duration: number?) -> (),
	watch: (self: Channel, fields: Fields?, options: WatchOptions?) -> Watch,
	time: (self: Channel, action: string?) -> (Fields?) -> number,
	measure: <T>(self: Channel, action: string?, callback: () -> T) -> (T, number),
}

export type Client = {
	isActive: (self: Client) -> boolean,
	setTheme: (self: Client, theme: Theme?) -> (),
	setTemplate: (self: Client, template: any, blacklist: any?) -> (),
	mount: (self: Client, parent: Instance?, options: ClientOptions?) -> (),
	unmount: (self: Client) -> (),
	push: (self: Client, event: Event | string) -> (),
	dismiss: (self: Client, key: string) -> (),
	begin: (self: Client, scope: string?, action: string?) -> Token,
	finish: (self: Client, token: Token, fields: Fields?) -> number,
	record: (self: Client, scope: string?, action: string?, elapsedMs: number?, fields: Fields?) -> (),
	time: (self: Client, scope: string?, action: string?) -> (Fields?) -> number,
	measure: <T>(self: Client, scope: string?, action: string?, callback: () -> T) -> (T, number),
	watch: (self: Client, key: string, fields: Fields?, options: WatchOptions?) -> Watch,
	graph: (self: Client, name: string, options: GraphOptions?) -> GraphHandle,
	inspect: (self: Client, scope: string?, value: any, duration: number?) -> (),
	emit: (self: Client, tone: Tone, scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	channel: (self: Client, scope: string) -> Channel,
	group: (self: Client, scope: string) -> Channel,
	raycast: (self: Client, scope: string?, origin: Vector3, direction: Vector3, params: RaycastParams?) -> RaycastResult?,
	spherecast: (self: Client, scope: string?, origin: Vector3, radius: number, direction: Vector3, params: RaycastParams?) -> RaycastResult?,
	blockcast: (self: Client, scope: string?, cframe: CFrame, size: Vector3, direction: Vector3, params: RaycastParams?) -> RaycastResult?,
	trace: (self: Client, scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	info: (self: Client, scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	phase: (self: Client, scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	success: (self: Client, scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	warn: (self: Client, scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	fail: (self: Client, scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	error: (self: Client, scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	clear: (self: Client) -> (),
	destroy: (self: Client) -> (),
}

export type LoriApi = {
	Templates: { [string]: any },
	Themes: { [string]: Theme },
	create: (options: ClientOptions?) -> Client,
	mount: (parent: Instance?, options: ClientOptions?) -> (),
	unmount: () -> (),
	destroy: () -> (),
	setTheme: (theme: Theme?) -> (),
	setTemplate: (template: any, blacklist: any?) -> (),
	push: (event: Event | string) -> (),
	dismiss: (key: string) -> (),
	begin: (scope: string?, action: string?) -> Token,
	finish: (token: Token, fields: Fields?) -> number,
	record: (scope: string?, action: string?, elapsedMs: number?, fields: Fields?) -> (),
	time: (scope: string?, action: string?) -> (Fields?) -> number,
	measure: <T>(scope: string?, action: string?, callback: () -> T) -> (T, number),
	watch: (key: string, fields: Fields?, options: WatchOptions?) -> Watch,
	graph: (name: string, options: GraphOptions?) -> GraphHandle,
	inspect: (scope: string?, value: any, duration: number?) -> (),
	channel: (scope: string) -> Channel,
	group: (scope: string) -> Channel,
	raycast: (scope: string?, origin: Vector3, direction: Vector3, params: RaycastParams?) -> RaycastResult?,
	spherecast: (scope: string?, origin: Vector3, radius: number, direction: Vector3, params: RaycastParams?) -> RaycastResult?,
	blockcast: (scope: string?, cframe: CFrame, size: Vector3, direction: Vector3, params: RaycastParams?) -> RaycastResult?,
	trace: (scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	info: (scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	phase: (scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	success: (scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	warn: (scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	fail: (scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	error: (scope: string?, action: string?, fields: Fields?, duration: number?) -> (),
	clear: () -> (),
}

return {}

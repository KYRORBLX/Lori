type Tone = "trace" | "phase" | "success" | "warn" | "error";

type Fields = Record<string, unknown>;

interface LoriTheme {
	trace?: Color3;
	phase?: Color3;
	success?: Color3;
	warn?: Color3;
	error?: Color3;
	key?: Color3;
	value?: Color3;
	muted?: Color3;
	text?: Color3;
	background?: Color3;
}

interface LoriEvent {
	tone?: Tone;
	scope?: string;
	action?: string;
	fields?: Fields;
	key?: string;
	duration?: number;
	sticky?: boolean;
	liveInterval?: number;
}

interface LoriToken {
	scope: string;
	action: string;
	started: number;
}

interface LoriWatch {
	disconnect(): void;
}

interface LoriGraphOptions {
	tone?: Tone;
	style?: "bars";
	unit?: string;
	range?: [number, number];
	warnAt?: number;
	failAt?: number;
	warnBelow?: number;
	failBelow?: number;
	format?: (value: number) => unknown;
}

interface LoriGraph {
	push(value: number): void;
	rescale(factor: number): void;
	remove(): void;
}

interface LoriItemBlacklist {
	Blacklist: string[];
	addItem(name: string): LoriItemBlacklist;
	FPS(): LoriItemBlacklist;
	Frame(): LoriItemBlacklist;
	Memory(): LoriItemBlacklist;
	Ping(): LoriItemBlacklist;
	Pressure(): LoriItemBlacklist;
}

interface LoriChannel {
	trace(action?: string, fields?: Fields, duration?: number): void;
	info(action?: string, fields?: Fields, duration?: number): void;
	phase(action?: string, fields?: Fields, duration?: number): void;
	success(action?: string, fields?: Fields, duration?: number): void;
	warn(action?: string, fields?: Fields, duration?: number): void;
	fail(action?: string, fields?: Fields, duration?: number): void;
	error(action?: string, fields?: Fields, duration?: number): void;
	watch(fields: Fields, options?: Fields): LoriWatch;
	time(action?: string): (fields?: Fields) => number;
	measure<T>(action: string | undefined, callback: () => T): LuaTuple<[T, number]>;
}

interface LoriOptions extends Record<string, unknown> {
	config?: Record<string, unknown>;
	theme?: LoriTheme;
	template?: unknown;
	templateBlacklist?: LoriItemBlacklist | string[];
	anchor?: "tr" | "tl" | "br" | "bl" | "topRight" | "topLeft" | "bottomRight" | "bottomLeft" | "top-right" | "top-left" | "bottom-right" | "bottom-left";
	rightOffset?: number;
	leftOffset?: number;
	topOffset?: number;
	bottomOffset?: number;
	cornerRadius?: number;
}

interface LoriApi {
	mount(parent?: Instance, options?: LoriOptions): void;
	unmount(): void;
	destroy(): void;
	setTheme(theme: LoriTheme): void;
	setTemplate(template: unknown): void;
	push(event?: LoriEvent | string): void;
	dismiss(key: string): void;
	clear(): void;

	begin(scope?: string, action?: string): LoriToken;
	finish(token: LoriToken, fields?: Fields): number;
	record(scope?: string, action?: string, elapsedMs?: number, fields?: Fields): void;
	time(scope?: string, action?: string): (fields?: Fields) => number;
	measure<T>(scope: string | undefined, action: string | undefined, callback: () => T): LuaTuple<[T, number]>;
	watch(key: string, fields: Fields, options?: Fields): LoriWatch;
	graph(name: string, options?: LoriGraphOptions): LoriGraph;
	inspect(scope: string | undefined, value: unknown, duration?: number): void;
	channel(scope: string): LoriChannel;
	group(scope: string): LoriChannel;

	raycast(scope: string | undefined, origin: Vector3, direction: Vector3, params?: RaycastParams): RaycastResult | undefined;
	spherecast(scope: string | undefined, origin: Vector3, radius: number, direction: Vector3, params?: RaycastParams): RaycastResult | undefined;
	blockcast(scope: string | undefined, cframe: CFrame, size: Vector3, direction: Vector3, params?: RaycastParams): RaycastResult | undefined;

	trace(scope?: string, action?: string, fields?: Fields, duration?: number): void;
	info(scope?: string, action?: string, fields?: Fields, duration?: number): void;
	phase(scope?: string, action?: string, fields?: Fields, duration?: number): void;
	success(scope?: string, action?: string, fields?: Fields, duration?: number): void;
	warn(scope?: string, action?: string, fields?: Fields, duration?: number): void;
	fail(scope?: string, action?: string, fields?: Fields, duration?: number): void;
	error(scope?: string, action?: string, fields?: Fields, duration?: number): void;
}

interface LoriStatic extends LoriApi {
	create(options?: LoriOptions): LoriApi;
	Templates: {
		Performance: () => unknown;
		Empty: () => unknown;
		ItemBlacklister: {
			New(): LoriItemBlacklist;
		};
	};
	Themes: {
		Default: Required<LoriTheme>;
	};
}

declare const Lori: LoriStatic;
export = Lori;

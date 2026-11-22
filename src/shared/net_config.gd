class_name NetConfig
extends RefCounted
## Общие сетевые константы клиента и сервера.

const PROTOCOL_VERSION := 1
const DEFAULT_PORT := 7777
const MAX_CLIENTS := 256
const DEFAULT_HOST := "127.0.0.1"


## Клиент и сервер обязаны совпадать по версии протокола.
static func is_compatible(client_version: int) -> bool:
	return client_version == PROTOCOL_VERSION

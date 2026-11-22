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


static func encode_version(version: int) -> PackedByteArray:
	var packet := PackedByteArray()
	packet.resize(4)
	packet.encode_u32(0, version)
	return packet


static func decode_version(packet: PackedByteArray) -> int:
	return packet.decode_u32(0) if packet.size() == 4 else -1

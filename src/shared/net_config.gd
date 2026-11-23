class_name NetConfig
extends RefCounted
## Общие сетевые константы клиента и сервера.

const PROTOCOL_VERSION := 3
const DEFAULT_PORT := 7777
const MAX_CLIENTS := 256
const DEFAULT_HOST := "127.0.0.1"
const LOGIN_KEY := 1
const RESUME_SESSION := 2
const SESSION_GRANTED := 3
const SECRET_BYTES := 32


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


static func encode_session(kind: int, secret: PackedByteArray) -> PackedByteArray:
	var packet := encode_version(PROTOCOL_VERSION)
	packet.append(kind)
	packet.append_array(secret)
	return packet


static func decode_session(packet: PackedByteArray, kind: int) -> PackedByteArray:
	if packet.size() != 5 + SECRET_BYTES or not is_compatible(packet.decode_u32(0)):
		return PackedByteArray()
	if packet[4] != kind:
		return PackedByteArray()
	return packet.slice(5)

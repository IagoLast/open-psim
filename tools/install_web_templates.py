"""Install only web templates from the official archive using HTTP byte ranges."""
import io
import pathlib
import struct
import sys
import urllib.request
import zipfile
import zlib

version = sys.argv[1] if len(sys.argv) > 1 else "4.7.2"
url = f"https://github.com/godotengine/godot/releases/download/{version}-stable/Godot_v{version}-stable_export_templates.tpz"
with urllib.request.urlopen(urllib.request.Request(url, method="HEAD")) as response:
    target = response.url
    size = int(response.headers["Content-Length"])

def read_range(start, end):
    request = urllib.request.Request(target, headers={"Range": f"bytes={start}-{end}"})
    with urllib.request.urlopen(request) as response:
        if response.status != 206:
            raise RuntimeError("Server does not support partial downloads")
        return response.read()

tail = read_range(size - 65536, size - 1)
end = tail.rfind(b"PK\x05\x06")
fields = struct.unpack_from("<4s4H2LH", tail, end)
central_size, central_offset = fields[5:7]
central = read_range(central_offset, central_offset + central_size - 1)
offset = 0
destination = pathlib.Path.home() / "Library/Application Support/Godot/export_templates" / f"{version}.stable"
if sys.platform != "darwin":
    destination = pathlib.Path.home() / ".local/share/godot/export_templates" / f"{version}.stable"
destination.mkdir(parents=True, exist_ok=True)
while offset < len(central):
    entry = struct.unpack_from("<4s6H3L5H2L", central, offset)
    name_length, extra_length, comment_length = entry[10:13]
    name = central[offset + 46:offset + 46 + name_length].decode()
    offset += 46 + name_length + extra_length + comment_length
    if pathlib.PurePosixPath(name).name not in ("web_nothreads_release.zip", "web_nothreads_debug.zip", "version.txt"):
        continue
    compressed_size, local_offset = entry[8], entry[16]
    header = read_range(local_offset, local_offset + 29)
    local = struct.unpack("<4s5H3L2H", header)
    start = local_offset + 30 + local[9] + local[10]
    payload = read_range(start, start + compressed_size - 1)
    content = zlib.decompress(payload, -15) if entry[4] == 8 else payload
    if zlib.crc32(content) != entry[7]:
        raise RuntimeError("CRC mismatch")
    output = destination / pathlib.PurePosixPath(name).name
    output.write_bytes(content)
    print(output, len(content), flush=True)

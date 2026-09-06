"""Named random channels: adding a detail never shifts another parameter's RNG.

Builders accept Variation(seed, parameters); omitted variation preserves canonicals.
Amounts are bounded by variants.py before any output is written.
"""
import hashlib


class Variation:
    def __init__(self, seed=0, parameters=None):
        self.seed = seed
        self.parameters = parameters or {}

    def unit(self, key):
        value = hashlib.sha256(f"open-psim-art-v1:{self.seed}:{key}".encode()).digest()
        return int.from_bytes(value[:8], "big") / (2**64 - 1)

    def offset(self, key, parameter):
        return (self.unit(key) * 2 - 1) * self.parameters.get(parameter, 0)

    def factor(self, key, parameter):
        return 1 + self.offset(key, parameter)

    def lobe(self, key, x, y, z, radius):
        return (x + self.offset(key+".x", "spread"),
                y + self.offset(key+".y", "spread"),
                z * self.factor("height", "height") + self.offset(key+".z", "spread"),
                radius * self.factor(key+".radius", "crown"))


CANONICAL = Variation()

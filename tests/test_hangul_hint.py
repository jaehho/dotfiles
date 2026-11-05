"""hypr-hangul-hint's key table must be what libhangul's 2-set types."""

import ctypes
import ctypes.util
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
import string
import unittest

SCRIPT = (Path(__file__).resolve().parent.parent
          / "home/hypr/.local/bin/hypr-hangul-hint")


def load_script():
    loader = SourceFileLoader("hypr_hangul_hint", str(SCRIPT))
    module = module_from_spec(spec_from_loader(loader.name, loader))
    loader.exec_module(module)
    return module


def load_libhangul():
    path = ctypes.util.find_library("hangul")
    if not path:
        raise unittest.SkipTest("libhangul is not installed")
    lib = ctypes.CDLL(path)
    lib.hangul_ic_new.restype = ctypes.c_void_p
    lib.hangul_ic_new.argtypes = [ctypes.c_char_p]
    lib.hangul_ic_process.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.hangul_ic_reset.argtypes = [ctypes.c_void_p]
    lib.hangul_ic_flush.restype = ctypes.POINTER(ctypes.c_uint32)
    lib.hangul_ic_flush.argtypes = [ctypes.c_void_p]
    lib.hangul_ic_get_commit_string.restype = ctypes.POINTER(ctypes.c_uint32)
    lib.hangul_ic_get_commit_string.argtypes = [ctypes.c_void_p]
    lib.hangul_ic_get_preedit_string.restype = ctypes.POINTER(ctypes.c_uint32)
    lib.hangul_ic_get_preedit_string.argtypes = [ctypes.c_void_p]
    lib.hangul_jamo_to_cjamo.restype = ctypes.c_uint32
    lib.hangul_jamo_to_cjamo.argtypes = [ctypes.c_uint32]
    return lib


def ucs4(pointer):
    out = []
    for char in pointer:
        if not char:
            break
        out.append(char)
    return out


class Hangul:
    def __init__(self):
        self.lib = load_libhangul()
        self.ic = self.lib.hangul_ic_new(b"2")

    def type(self, keys):
        """What the keys commit, with the last syllable flushed."""
        self.lib.hangul_ic_reset(self.ic)
        out = []
        for key in keys:
            self.lib.hangul_ic_process(self.ic, ord(key))
            out += ucs4(self.lib.hangul_ic_get_commit_string(self.ic))
        out += ucs4(self.lib.hangul_ic_flush(self.ic))
        return "".join(chr(c) for c in out)

    def single(self, key):
        """The compatibility jamo one key shows while it is being typed."""
        self.lib.hangul_ic_reset(self.ic)
        self.lib.hangul_ic_process(self.ic, ord(key))
        pre = ucs4(self.lib.hangul_ic_get_preedit_string(self.ic))
        return "".join(chr(self.lib.hangul_jamo_to_cjamo(c)) for c in pre)


class KeyTable(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.hint = load_script()
        cls.hangul = Hangul()

    def keys(self):
        return [key for row in self.hint.ROWS for key in row]

    def test_every_letter_once(self):
        letters = sorted(latin for latin, _, _ in self.keys())
        self.assertEqual(letters, list(string.ascii_lowercase))

    def test_jamo_match_libhangul(self):
        for latin, jamo, _ in self.keys():
            self.assertEqual(self.hangul.single(latin), jamo, latin)

    def test_shifted_match_libhangul(self):
        for latin, jamo, shifted in self.keys():
            self.assertEqual(self.hangul.single(latin.upper()),
                             shifted or jamo, latin.upper())


class Follow(unittest.TestCase):
    """Visibility follows fcitx5; a flip holds until the language changes."""

    def setUp(self):
        self.state = load_script().Visibility()

    def test_hidden_until_hangul(self):
        self.state.update(False)
        self.assertFalse(self.state.visible)
        self.assertTrue(self.state.update(True))
        self.assertTrue(self.state.visible)

    def test_unchanged_state_reports_no_change(self):
        self.state.update(True)
        self.assertFalse(self.state.update(True))

    def test_flip_hides_and_holds(self):
        self.state.update(True)
        self.state.flip()
        self.assertFalse(self.state.visible)
        self.assertFalse(self.state.update(True))
        self.assertFalse(self.state.visible)

    def test_flip_shows_in_english(self):
        self.state.update(False)
        self.state.flip()
        self.assertTrue(self.state.visible)

    def test_language_change_ends_a_flip(self):
        self.state.update(True)
        self.state.flip()
        self.state.update(False)
        self.state.update(True)
        self.assertTrue(self.state.visible)

    def test_always_ignores_everything(self):
        state = load_script().Visibility(always=True)
        state.update(False)
        state.flip()
        self.assertTrue(state.visible)


if __name__ == "__main__":
    unittest.main()

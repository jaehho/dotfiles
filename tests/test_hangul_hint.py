"""hypr-hangul-hint's key table must be what libhangul's 2-set types."""

import ctypes
import ctypes.util
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
import re
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


class Lighting(unittest.TestCase):
    """Key presses reach the right key, read from raw input_event bytes."""

    @classmethod
    def setUpClass(cls):
        cls.hint = load_script()

    def event(self, kind, code, value):
        return self.hint.INPUT_EVENT.pack(0, 0, kind, code, value)

    def test_codes_match_the_kernel_header(self):
        header = Path("/usr/include/linux/input-event-codes.h")
        if not header.exists():
            self.skipTest("linux headers are not installed")
        text = header.read_text()
        for code, letter in self.hint.KEY_CODES.items():
            match = re.search(
                rf"#define KEY_{letter.upper()}\s+(\d+)\b", text)
            self.assertEqual(int(match.group(1)), code, letter)

    def test_every_key_on_the_board_can_light(self):
        board = {latin for row in self.hint.ROWS for latin, _, _ in row}
        self.assertEqual(set(self.hint.KEY_CODES.values()), board)

    def test_down_and_up(self):
        data = self.event(1, 33, 1) + self.event(1, 33, 0)
        self.assertEqual(self.hint.key_events(data),
                         [("f", True), ("f", False)])

    def test_repeat_other_keys_and_sync_are_ignored(self):
        data = (self.event(1, 33, 2) + self.event(1, 57, 1)
                + self.event(0, 0, 0) + self.event(4, 4, 33))
        self.assertEqual(self.hint.key_events(data), [])

    def test_a_cut_off_event_is_dropped(self):
        data = self.event(1, 36, 1) + self.event(1, 37, 1)[:10]
        self.assertEqual(self.hint.key_events(data), [("j", True)])


class Cursor(unittest.TestCase):
    """Where the cursor is against the overlay, from Hyprland's IPC."""

    @classmethod
    def setUpClass(cls):
        cls.hint = load_script()

    def layers(self, namespace="hangul-hint"):
        return {"eDP-1": {"levels": {
            "0": [{"namespace": "waybar", "x": 0, "y": 0, "w": 1920, "h": 40}],
            "3": [{"namespace": namespace, "x": 636, "y": 810,
                   "w": 648, "h": 214}]}}}

    def test_finds_the_layer_by_namespace(self):
        monitors = [{"name": "eDP-1", "x": 0, "y": 0}]
        self.assertEqual(self.hint.find_overlay(self.layers(), monitors),
                         (636, 810, 648, 214))

    def test_the_namespace_matches_the_one_the_window_sets(self):
        # hyprland.lua's blur rule and the IPC lookup both key on it.
        source = SCRIPT.read_text()
        self.assertIn("set_namespace(self.window, NAMESPACE)", source)
        self.assertEqual(self.hint.NAMESPACE, "hangul-hint")

    def test_a_monitor_offset_is_added(self):
        monitors = [{"name": "eDP-1", "x": 2560, "y": 100}]
        self.assertEqual(self.hint.find_overlay(self.layers(), monitors),
                         (3196, 910, 648, 214))

    def test_no_layer_no_position(self):
        self.assertIsNone(self.hint.find_overlay(self.layers("other"), []))
        self.assertIsNone(self.hint.find_overlay(None, None))

    def test_cursor_over_the_board_is_in_its_own_pixels(self):
        overlay = (636, 810, 648, 214)
        self.assertEqual(self.hint.hole_centre((700, 900), overlay), (64, 90))

    def test_cursor_just_outside_still_clears_its_edge(self):
        overlay = (636, 810, 648, 214)
        self.assertEqual(self.hint.hole_centre((600, 900), overlay),
                         (-36, 90))

    def test_cursor_far_away_clears_nothing(self):
        overlay = (636, 810, 648, 214)
        self.assertIsNone(self.hint.hole_centre((100, 100), overlay))
        self.assertIsNone(self.hint.hole_centre((700, 100), overlay))

    def test_unknown_cursor_or_layer_clears_nothing(self):
        self.assertIsNone(self.hint.hole_centre(None, (0, 0, 10, 10)))
        self.assertIsNone(self.hint.hole_centre((5, 5), None))


if __name__ == "__main__":
    unittest.main()

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "godot_gate.py"


def load_module():
    spec = importlib.util.spec_from_file_location("godot_gate_under_test", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class GodotGateTest(unittest.TestCase):
    def setUp(self):
        self.module = load_module()

    def test_project_path_forms(self):
        self.assertEqual(self.module._project_path(["--path", "/repo", "--headless"]), "/repo")
        self.assertEqual(self.module._project_path(["--path=/other"]), "/other")
        self.assertEqual(self.module._project_path([]), ".")

    def test_lock_exclusion_and_release_on_current_platform(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "slot.lock"
            first = path.open("a+b")
            second = path.open("a+b")
            try:
                self.module._prepare_lock_file(first)
                self.module._prepare_lock_file(second)
                self.assertTrue(self.module._try_lock(first))
                self.assertFalse(self.module._try_lock(second))
                self.module._unlock(first)
                self.assertTrue(self.module._try_lock(second))
                self.module._unlock(second)
            finally:
                first.close()
                second.close()


if __name__ == "__main__":
    unittest.main()

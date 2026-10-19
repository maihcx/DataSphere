import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "link_skills.py"


class LinkSkillsPathTests(unittest.TestCase):
    def test_paths_follow_script_workspace_and_current_user_home(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            workspace = root / "portable-skill-repo"
            copied_script = workspace / "scripts" / "link_skills.py"
            copied_script.parent.mkdir(parents=True)
            shutil.copy2(SCRIPT, copied_script)
            fake_home = root / "different-user"

            spec = importlib.util.spec_from_file_location(
                "portable_link_skills", copied_script
            )
            self.assertIsNotNone(spec)
            self.assertIsNotNone(spec.loader)
            module = importlib.util.module_from_spec(spec)
            with patch("pathlib.Path.home", return_value=fake_home):
                spec.loader.exec_module(module)

            self.assertEqual(module.WORKSPACE, workspace.resolve())
            self.assertEqual(
                module.CONFIG_ROOTS,
                [
                    fake_home / ".gemini" / "config" / "skills",
                    fake_home / ".gemini" / "skills",
                    fake_home / ".claude" / "skills",
                    fake_home / ".agents" / "skills",
                ],
            )


if __name__ == "__main__":
    unittest.main()

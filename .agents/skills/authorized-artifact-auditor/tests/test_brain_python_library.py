import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "web-app-scanner" / "scripts" / "brain_python_library.py"


class BrainPythonLibraryTests(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *map(str, args)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )

    def test_sync_copies_relevant_code_without_executing_it(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-a" / "scratch" / "scan_xss.py"
            source.parent.mkdir(parents=True)
            source.write_text(
                "def find_unescaped_html(source):\n"
                "    return '.innerHTML =' in source\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            self.assertEqual(index["stats"]["copied"], 1)
            entry = index["entries"][0]
            self.assertEqual(entry["status"], "copied")
            self.assertIn("xss", entry["categories"])
            self.assertIn("XSS", entry["description"])
            copied = library / entry["library_path"]
            self.assertEqual(copied.read_text(encoding="utf-8"), source.read_text(encoding="utf-8"))

    def test_sync_blocks_sensitive_or_active_top_level_scripts_and_redacts_index(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-b" / "scratch" / "admin_probe.py"
            source.parent.mkdir(parents=True)
            secret = "live-super-secret-token-value"
            target_url = "https://private.example.test/admin"
            source.write_text(
                "import requests\n"
                f"API_TOKEN = '{secret}'\n"
                f"requests.get('{target_url}')\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            raw_index = (library / "index.json").read_text(encoding="utf-8")
            index = json.loads(raw_index)
            entry = index["entries"][0]
            self.assertEqual(entry["status"], "blocked")
            self.assertIn("secret-literal", entry["block_reasons"])
            self.assertIn("top-level-network", entry["block_reasons"])
            self.assertNotIn("library_path", entry)
            self.assertNotIn(secret, raw_index)
            self.assertNotIn(target_url, raw_index)
            self.assertEqual(list((library / "files").rglob("*.py")), [])

    def test_sync_blocks_session_network_call_at_import(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-network" / "scratch" / "probe.py"
            source.parent.mkdir(parents=True)
            source.write_text(
                "import requests\n"
                "session = requests.Session()\n"
                "session.get('https://example.test/health')\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            self.assertIn("top-level-network", index["entries"][0]["block_reasons"])

    def test_sync_blocks_path_deletion_at_import(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-delete" / "scratch" / "cleanup.py"
            source.parent.mkdir(parents=True)
            source.write_text(
                "from pathlib import Path\n"
                "Path('output.txt').unlink()\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            self.assertIn("top-level-destructive", index["entries"][0]["block_reasons"])

    def test_sync_blocks_file_write_at_import(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-write" / "scratch" / "write_report.py"
            source.parent.mkdir(parents=True)
            source.write_text(
                "with open('report.txt', mode='w', encoding='utf-8') as report:\n"
                "    report.write('done')\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            self.assertIn("top-level-file-write", index["entries"][0]["block_reasons"])

    def test_sync_blocks_subprocess_at_import(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-process" / "scratch" / "run_tool.py"
            source.parent.mkdir(parents=True)
            source.write_text(
                "from subprocess import run as launch\n"
                "launch(['helper', '--check'])\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            self.assertIn("top-level-subprocess", index["entries"][0]["block_reasons"])

    def test_sync_blocks_unresolved_local_helper_at_import(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-helper-call" / "scratch" / "generate_project.py"
            source.parent.mkdir(parents=True)
            source.write_text(
                "from pathlib import Path\n"
                "def write_project():\n"
                "    Path('project.txt').write_text('generated', encoding='utf-8')\n"
                "write_project()\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            self.assertIn("top-level-call", index["entries"][0]["block_reasons"])

    def test_sync_resolves_network_alias_in_function_default(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-default" / "scratch" / "fetch_default.py"
            source.parent.mkdir(parents=True)
            source.write_text(
                "from requests import get as fetch\n"
                "def parse(response=fetch('https://example.test/data')):\n"
                "    return response.text\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            self.assertIn("top-level-network", index["entries"][0]["block_reasons"])

    def test_sync_marks_network_helpers_reference_only(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-helper" / "scratch" / "fetch_map.py"
            source.parent.mkdir(parents=True)
            source.write_text(
                "import requests\n"
                "def fetch_map(url):\n"
                "    return requests.get(url, timeout=5).text\n"
                "if __name__ == '__main__':\n"
                "    print(fetch_map('https://example.test/app.js.map'))\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            entry = index["entries"][0]
            self.assertEqual(entry["status"], "copied")
            self.assertEqual(entry["reuse_level"], "reference-only")

    def test_sync_marks_socket_and_subprocess_helpers_reference_only(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            socket_source = brain / "session-socket" / "scratch" / "scan_port.py"
            process_source = brain / "session-command" / "scratch" / "run_check.py"
            socket_source.parent.mkdir(parents=True)
            process_source.parent.mkdir(parents=True)
            socket_source.write_text(
                "import socket\n"
                "def check_port(host, port):\n"
                "    client = socket.socket()\n"
                "    return client.connect_ex((host, port))\n",
                encoding="utf-8",
            )
            process_source.write_text(
                "import subprocess\n"
                "def run_check():\n"
                "    return subprocess.run(['helper', '--check'], check=False)\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            self.assertEqual({entry["status"] for entry in index["entries"]}, {"copied"})
            self.assertEqual(
                {entry["reuse_level"] for entry in index["entries"]}, {"reference-only"}
            )

    def test_sync_blocks_static_authorization_and_kebab_case_passwords(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            auth = brain / "session-auth" / "scratch" / "auth_header.py"
            admin = brain / "session-admin" / "scratch" / "admin_header.py"
            auth.parent.mkdir(parents=True)
            admin.parent.mkdir(parents=True)
            auth.write_text(
                "HEADERS = {'Authorization': 'Bearer ' + 'private-value'}\n",
                encoding="utf-8",
            )
            admin.write_text(
                "HEADERS = {'X-Admin-Password': 'private-value'}\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            raw_index = (library / "index.json").read_text(encoding="utf-8")
            index = json.loads(raw_index)
            self.assertEqual({entry["status"] for entry in index["entries"]}, {"blocked"})
            self.assertTrue(
                all("secret-literal" in entry["block_reasons"] for entry in index["entries"])
            )
            self.assertNotIn("private-value", raw_index)

    def test_sync_blocks_static_credential_uri_and_generated_secret_template(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            uri_source = brain / "session-uri" / "scratch" / "configure.py"
            template_source = brain / "session-template" / "scratch" / "generate_routes.py"
            uri_source.parent.mkdir(parents=True)
            template_source.parent.mkdir(parents=True)
            uri_source.write_text(
                "def configure(value):\n"
                "    return value\n"
                "DATABASE = configure('postgresql://deploy:' + 'private-value@db/app')\n",
                encoding="utf-8",
            )
            template_source.write_text(
                'SOURCE = """const secret = process.env.JWT_SECRET || \'private-value\';"""\n',
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            raw_index = (library / "index.json").read_text(encoding="utf-8")
            index = json.loads(raw_index)
            self.assertEqual({entry["status"] for entry in index["entries"]}, {"blocked"})
            self.assertTrue(
                all("secret-literal" in entry["block_reasons"] for entry in index["entries"])
            )
            self.assertNotIn("private-value", raw_index)

    def test_sync_blocks_sensitive_bytes_literal(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-bytes" / "scratch" / "signing.py"
            source.parent.mkdir(parents=True)
            source.write_text(
                "JWT_SECRET = b'private-binary-value'\n"
                "def sign(payload):\n"
                "    return payload + JWT_SECRET\n",
                encoding="utf-8",
            )

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            raw_index = (library / "index.json").read_text(encoding="utf-8")
            index = json.loads(raw_index)
            self.assertEqual(index["entries"][0]["status"], "blocked")
            self.assertIn("secret-literal", index["entries"][0]["block_reasons"])
            self.assertNotIn("private-binary-value", raw_index)

    def test_sync_excludes_generated_system_directories(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            ignored = brain / ".system_generated" / "ignored.py"
            ignored.parent.mkdir(parents=True)
            ignored.write_text("def scan_xss():\n    return True\n", encoding="utf-8")

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            self.assertEqual(index["stats"]["scanned"], 0)
            self.assertEqual(index["entries"], [])

    def test_sync_suppresses_warnings_from_legacy_source_strings(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-old" / "scratch" / "regex_helper.py"
            source.parent.mkdir(parents=True)
            source.write_text("PATTERN = '\\s+'\n", encoding="utf-8")

            result = self.run_cli("sync", brain, "--library", library)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("SyntaxWarning", result.stderr)

    def test_search_returns_matching_library_entries_as_json(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-c" / "scratch" / "check_sourcemap.py"
            source.parent.mkdir(parents=True)
            source.write_text(
                "def inspect_source_map(path):\n"
                "    return path.suffix == '.map'\n",
                encoding="utf-8",
            )
            sync_result = self.run_cli("sync", brain, "--library", library)
            self.assertEqual(sync_result.returncode, 0, sync_result.stderr)

            search_result = self.run_cli(
                "search", "source map", "--library", library, "--json"
            )

            self.assertEqual(search_result.returncode, 0, search_result.stderr)
            matches = json.loads(search_result.stdout)
            self.assertEqual(len(matches), 1)
            self.assertEqual(matches[0]["name"], "check_sourcemap.py")
            self.assertIn("source-map", matches[0]["categories"])

    def test_verify_detects_a_tampered_copied_file(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-verify" / "scratch" / "scan_xss.py"
            source.parent.mkdir(parents=True)
            source.write_text("def scan_xss():\n    return []\n", encoding="utf-8")
            sync_result = self.run_cli("sync", brain, "--library", library)
            self.assertEqual(sync_result.returncode, 0, sync_result.stderr)

            valid_result = self.run_cli("verify", "--library", library)
            self.assertEqual(valid_result.returncode, 0, valid_result.stderr)
            self.assertIn("1 copied files verified", valid_result.stdout)

            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            copied = library / index["entries"][0]["library_path"]
            copied.write_text("def changed():\n    return True\n", encoding="utf-8")
            tampered_result = self.run_cli("verify", "--library", library)

            self.assertEqual(tampered_result.returncode, 2)
            self.assertIn("checksum mismatch", tampered_result.stderr.lower())

    def test_verify_accepts_git_line_ending_normalization(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            brain = root / "brain"
            library = root / "python-library"
            source = brain / "session-eol" / "scratch" / "scan_xss.py"
            source.parent.mkdir(parents=True)
            source.write_bytes(b"def scan_xss():\n    return []\n")
            sync_result = self.run_cli("sync", brain, "--library", library)
            self.assertEqual(sync_result.returncode, 0, sync_result.stderr)

            index = json.loads((library / "index.json").read_text(encoding="utf-8"))
            copied = library / index["entries"][0]["library_path"]
            copied.write_bytes(copied.read_bytes().replace(b"\n", b"\r\n"))

            verify_result = self.run_cli("verify", "--library", library)
            self.assertEqual(verify_result.returncode, 0, verify_result.stderr)

    def test_verify_rejects_nonportable_paths_and_uri_schemes(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            library = Path(temp_dir) / "python-library"
            library.mkdir()
            base_entry = {
                "id": "entry-1",
                "name": "helper.py",
                "description": "General Python utility.",
                "categories": [],
                "imports": [],
                "functions": [],
                "classes": [],
                "signals": {"syntax_valid": False},
                "reuse_level": "do-not-run",
                "status": "blocked",
                "block_reasons": ["syntax-error"],
            }
            unsafe_values = ("/home/user/helper.py", "C:/Users/name/helper.py", "ftp://host/file")

            for unsafe_value in unsafe_values:
                with self.subTest(unsafe_value=unsafe_value):
                    entry = {**base_entry, "source_relpath": unsafe_value}
                    index = {
                        "schema_version": 1,
                        "stats": {"scanned": 1, "copied": 0, "blocked": 1},
                        "entries": [entry],
                    }
                    (library / "index.json").write_text(json.dumps(index), encoding="utf-8")
                    result = self.run_cli("verify", "--library", library)
                    self.assertEqual(result.returncode, 2)

    def test_check_requires_only_the_standard_library(self):
        result = self.run_cli("--check")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("standard library only", result.stdout)


if __name__ == "__main__":
    unittest.main()

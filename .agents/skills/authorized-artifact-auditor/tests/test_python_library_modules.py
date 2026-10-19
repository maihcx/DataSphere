import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = ROOT / "web-app-scanner" / "python-library"
sys.path.insert(0, str(LIB_DIR))

import bundle_analyzer
import port_scanner
import security_headers
import sourcemap_extractor
import string_extractor


class PythonLibraryModulesTests(unittest.TestCase):
    def test_bundle_analyzer_finds_routes_and_tokens(self):
        sample_js = """
        const botToken = "123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ1234567";
        const apiUrl = '/api/v1/orders';
        localStorage.setItem("auth_token", "jwt123");
        function UserProfileComponent() { return null; }
        """
        findings = bundle_analyzer.analyze_bundle_content(sample_js, "test_bundle")
        self.assertIn("123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ1234567", findings["findings"]["telegram_bots"])
        self.assertIn("/api/v1/orders", findings["findings"]["api_routes"])
        self.assertIn("auth_token", findings["findings"]["localstorage_keys"])
        self.assertIn("UserProfileComponent", findings["react_components"])

    def test_port_scanner_specs_parsing(self):
        specs = "80,443,8080-8082, invalid, 70000"
        parsed = port_scanner.parse_port_specs(specs)
        self.assertEqual(parsed, [80, 443, 8080, 8081, 8082])

    def test_sourcemap_extractor_unpack(self):
        map_content = {
            "version": 3,
            "file": "bundle.js",
            "sources": ["src/app.js", "src/utils.js"],
            "sourcesContent": [
                "console.log('app');",
                "export const add = (a, b) => a + b;",
            ],
        }
        meta = sourcemap_extractor.parse_sourcemap_data(json.dumps(map_content))
        self.assertEqual(meta["sources_count"], 2)
        self.assertTrue(meta["has_content"])

        with tempfile.TemporaryDirectory() as td:
            out_dir = Path(td)
            unpacked = sourcemap_extractor.unpack_sources(meta, out_dir)
            self.assertEqual(unpacked, 2)
            self.assertTrue((out_dir / "src" / "app.js").is_file())
            self.assertEqual((out_dir / "src" / "app.js").read_text(encoding="utf-8"), "console.log('app');")

    def test_string_extractor_filters(self):
        with tempfile.TemporaryDirectory() as td:
            bin_file = Path(td) / "sample.bin"
            bin_file.write_bytes(b"\x00\x01\x02SECRET_TOKEN_VALUE\x00\x00ANOTHER_KEY_1234\x00\xffSHORT")
            strings = string_extractor.extract_printable_strings(bin_file, min_len=4, keywords=["secret", "key"])
            self.assertIn("SECRET_TOKEN_VALUE", strings)
            self.assertIn("ANOTHER_KEY_1234", strings)
            self.assertNotIn("SHORT", strings)

    def test_security_headers_recommended_structure(self):
        self.assertIn("strict-transport-security", security_headers.RECOMMENDED_HEADERS)
        self.assertIn("content-security-policy", security_headers.RECOMMENDED_HEADERS)
        self.assertIn("x-content-type-options", security_headers.RECOMMENDED_HEADERS)


if __name__ == "__main__":
    unittest.main()
